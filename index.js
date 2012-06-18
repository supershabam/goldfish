/*!
 * goldfish
 * Copyright(c) 2012 Ian Hansen <ian@supershabam.com>
 * MIT Licensed
 */
"use strict";

var util = require('util')
  , events = require('events')
  , NULL
  , EVICT_REASONS
  ;

EVICT_REASONS = {
  CAPACITY: 'capacity',
  EXPIRED: 'expired',
  MANUAL: 'manual'
};

/**
 * options:
 * + populate - function to run when getting a value that doesn't exist in the cache
 * + expires - time in miliseconds that a key can stay in the cache (null for no expiration)
 * + capacity - maximum number of items in the cache, older items will be evicted to make space (null for no max)
 * + cleanup - time in miliseconds between running the cleanup function to expire old items
 */
function Goldfish(options) {
  options = options || {};
  this._populate = options.populate || null;
  this._expires = options.expires || null;
  this._capacity = options.capacity || null;
  this._cleanupPeriod = options.cleanup || 60000;
  this._cache = {};
  this._newest = NULL;
  this._oldest = NULL;
  this._size = 0;
  this._cleanupInterval = null;

  // magical thisness
  this._cleanup = this._cleanup.bind(this);
}
util.inherits(Goldfish, events.EventEmitter);

/**
 * key - hashable value to fetch from cache or run populate function with
 * options:
 * + populate - override the populate function provided
 * + refresh - boolean whether or not to touch the key value so that it doesn't expire or get evicted for space (default: true)
 */
Goldfish.prototype.get = function(key, cb, options) {
  options = options || {};

  var populate = options.populate || this._populate
    , refresh = options.refresh ? true : false
    , expiresTime = this._expires ? this._expires + (new Date().getTime()) : -Infinity
    ;

  // before reading from local cache, expire this key if it's too old
  if (this._cache.hasOwnProperty(key) && this._cache[key].refreshed < expiresTime) {
    this._evict(key, EVICT_REASONS.expired);
  }

  // comence cache retreival
  if (this._cache.hasOwnProperty(key)) {
    if (refresh) this._refresh(key);

    // do callback on next cpu event (allow caller to operate truely asynchronously)
    process.nextTick(cb.bind({}, null, this._cache[key].value));
  } else {
    this._fetch(populate, key, cb);
  }
};

/**
 * force the eviction of a key
 * key - hashable value to evict from local cache
 */
Goldfish.prototype.evict = function(key, silent) {
  if (this._cache.hasOwnProperty(key)) {
    this._evict(key, EVICT_REASONS.MANUAL, silent);
  }
};

// events fired: evict, evict:expired, evict:manual, evict:capacity

Goldfish.prototype._fetch = function(populate, key, cb) {
  var self = this;

  populate(key, function(err, value) {
    if (err) return cb(err);

    self._insert(key, value);
    cb(null, value);
  });
};

Goldfish.prototype._insert = function(key, value) {
  var entry
    , capacity = this._capacity ? this._capacity : Infinity
    ;
  
  entry = {
    key: key,
    value: value,
    refreshed: new Date().getTime()
  };

  this._pushEntry(entry);
  this._cache[key] = entry;
  ++this._size;

  // evict oldest if we are now over capacity
  if (this._size > capacity) {
    this._evict(this._oldest.key, EVICT_REASONS.CAPACITY);
  }

  // start the cleanup thread if not already running
  if(!this._cleanupInterval) {
    this._cleanupInterval = setInterval(this._cleanup, this._cleanupPeriod);
  }
};

Goldfish.prototype._evict = function(key, reason, silent) {
  var entry = this._cache[key]
    , silent = silent ? true : false
    , env
    ;

  if(!entry) return;

  this._pullEntry(entry);
  delete this._cache[key];
  --this._size;

  env = {
    reason: reason,
    key: key,
    value: entry.value,
    refreshed: entry.refreshed
  };

  // let people know about this eviction
  if(!silent) {
    this.emit('evict', env);
    this.emit('evict:' + env.reason, env);
  }

  // stop cleanup thread if we are now empty
  if(this._size === 0) {
    clearInterval(this._cleanupInterval);
    this._cleanupInterval = null;
  }
};

Goldfish.prototype._pullEntry = function(entry) {
  // remove from middle
  if (entry.older !== NULL && entry.newer !== NULL) {
    entry.older.newer = entry.newer;
    entry.newer.older = entry.older;
  }

  // remove single entry
  if (this._oldest === entry && this._newest === entry) {
    this._oldest = NULL;
    this._newest = NULL;
  }

  // remove oldest in a series
  if (this._oldest === entry) {
    this._oldest = entry.newer;
    entry.newer.older = NULL;
  }

  // remove newest in a series
  if (this._newest === entry) {
    this._newest = entry.older;
    entry.older.newer = NULL;
  }
};

Goldfish.prototype._pushEntry = function(entry) {
  // first entry if there is no newest
  if (this._newest === NULL) {
    this._newest = entry;
    this._oldest = entry;
    entry.newer = NULL;
    entry.older = NULL;
  } 

  // adding to the front
  else {
    this._newest.newer = entry;
    entry.older = this._newest;
    entry.newer = NULL;
    this._newest = entry;    
  }
};

Goldfish.prototype._refresh = function(key) {
  var entry = this._cache[key];

  this._pullEntry(entry);
  this._pushEntry(entry);
  entry.refreshed = new Date().getTime();
};

// starting from the oldest, remove while timestamp is expired
Goldfish.prototype._cleanup = function() {
  var maxElapsed = this._expires ? this._expires : Infinity
    , now = new Date().getTime()
    ;

  while (this._oldest && (now - this._oldest.refreshed) > maxElapsed) {
    this._evict(this._oldest.key, EVICT_REASONS.EXPIRED);
  }
};

exports.createGoldfish = function(options) {
  return new Goldfish(options);
};
exports.EVICT_REASONS = EVICT_REASONS;