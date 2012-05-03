/*!
 * goldfish
 * Copyright(c) 2012 Ian Hansen <ian@supershabam.com>
 * MIT Licensed
 */

"use strict";

var _ = require('underscore')
  , util = require('util')
  , events = require('events')
  , NULL = {}
  , EVICT_REASONS;
  
EVICT_REASONS = {
  EXPIRED: 'expired',
  REPLACED: 'replaced'
};

/**
 * Initialize default values
 */
function Goldfish(timeout, loader, cleanupInterval) {
  var self = this;
  events.EventEmitter.call(this);
  
  this._timeout = timeout || 1000;
  this._cleanupInterval = cleanupInterval || 1000;
  this._loader = loader || this._defaultLoader;
  this._cache = {};
  
  (function cleanup() {
    self._cleanup.call(self);
    self._cleanupTimeout = setTimeout(cleanup, self._cleanupInterval);
  })();
}
util.inherits(Goldfish, events.EventEmitter);

/**
 * Get a value from the cache. If not found locally, use loader
 */
Goldfish.prototype.get = function(key, options) {
  var cb
    , loader    
    , self = this
    , value;
  
  // process options as cb or object
  if (_.isFunction(options)) {
    options = {
      cb: options
    };
  } else {
    options = options || {};
  }
  
  // prepare values
  cb = options.cb || function() {};
  loader = options.loader || this._loader;
  value = this._getValueFromCache(key);
    
  // return value from cache
  if(value !== NULL) {
    return cb(null, value);
  }
  
  // get the value using loader
  return loader(key, cb);
};

/**
 * Evict a key from the cache
 */
Goldfish.prototype.evict = function(key, reason) {
  var value = this._getValueFromCache(key);
  if (value !== NULL) {
    this._evict(key, value, reason);
  }
};

/**
 * Set a key into the cache with a timeout
 */
Goldfish.prototype.set = function(key, value, timeout) {
  timeout = timeout || this._timeout;
  
  this.evict(key, EVICT_REASONS.REPLACED);
  
  this._cache[key] = {
    value: value,
    timeout: new Date().getTime() + timeout
  };
};

/**
 * Default loader that merely complains that it couldn't load anything for you
 */
Goldfish.prototype._defaultLoader = function(key, cb) {
  return cb('key not found');
};

/**
 * Private helper to get a value from the cache, or expiring the value if too old
 */
Goldfish.prototype._getValueFromCache = function(key) {
  var now = new Date().getTime();
    
  if (this._cache.hasOwnProperty(key)) {
    if (this._cache[key].timeout < now) {
      this._evict(key, this._cache[key].value, EVICT_REASONS.EXPIRED);
      return NULL;
    }
    return this._cache[key].value;
  }
  return NULL;
};

/**
 * Private eviction removes key from cache and emits
 */
Goldfish.prototype._evict = function(key, value, reason) {
  this.emit('evict', key, value, reason);
  this.emit('evict:' + key, value, reason);
  delete this._cache[key];
}

/**
 * Evict old cache entries
 */
Goldfish.prototype._cleanup = function() {
  var self = this
    , now = new Date().getTime();
  
  this.emit('cleanup');  
  Object.keys(this._cache).forEach(function(key) {
    if (self._cache[key].timeout < now) {
      self.evict(key, EVICT_REASONS.EXPIRED);
    }
  });
};

module.exports.Goldfish = Goldfish;
