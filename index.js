/*!
 * goldfish
 * Copyright(c) 2012 Ian Hansen <ian@supershabam.com>
 * MIT Licensed
 */
"use strict";

var util = require('util')
  , events = require('events')
  , NULL
  ;

/**
 * options:
 * + populate - function to run when getting a value that doesn't exit in the cache
 * + expires - time in miliseconds that a key can stay in the cache (null for no expiration)
 * + capacity - maximum number of items in the cache, older items will be evicted to make space (null for no max)
 */
function Goldfish(options) {
  options = options || {};
  this._populate = options.populate || null;
  this._expires = options.expires || null;
  this._capacity = options.capacity || null;
  this._cache = {};
  this._newest = NULL;
  this._oldest = NULL;
  this._size = 0;
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
    ;

  // try evicting locally first if expired

  if (this._cache.hasOwnProperty(key)) {
    if (refresh) this._refresh(key);
    process.nextTick(cb.bind({}, null, this._cache[key].value));
  } else {
    this._fetch(populate, key, cb);
  }
}

/**
 * force the eviction of a key
 * key - hashable value to evict from local cache
 */
Goldfish.prototype.evict = function(key) {}

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
  var entry = {
    value: value,
    refreshed: new Date(),
    newer: NULL,
    older: this._newest
  };

  if (this._newest !== NULL) {
    this._newest.newer = entry;
  }

  this._newest = entry;

  if (this._oldest === NULL) {
    this._oldest = entry;
  }

  this._cache[key] = entry;
}

Goldfish.prototype._refresh = function(key) {
  var entry = this._cache[key];

  if (entry.older !== NULL) {
    entry.older.newer = entry.newer;
  }
  if (entry.newer !== NULL) {
    entry.newer.older = entry.older;
  }
  if (this._oldest === entry && entry.newer) {
    this._oldest = entry.newer;
  }

  entry.refreshed = new Date();
  entry.newer = NULL;
  if (this._newest !== entry) {
    entry.older = this._newest;
    this._newest.newer = entry;
    this._newest = entry;
  }
}

var g = new Goldfish();
g._insert('test', '1');
g._insert('another', '2');
g._insert('asldfk', '3');
g._refresh('asldfk');
console.log(g);