goldfish
========

[![Build Status](https://secure.travis-ci.org/SuperShabam/goldfish.png?branch=master)](http://travis-ci.org/SuperShabam/goldfish)

Evented JavaScript in-memory cache

Example
=======

Caching redis gets
------------------
```javascript
var redisClient = require('redis').createClient()
  , Goldfish = require('goldfish')
  , cache
  ;
  
cache = new Goldfish({
  // the populate function will be run when a value does not yet exist in the cache
  populate: function(key, cb) {
    redisClient.get(key, cb);
  },
  capacity: 1000, // keep at max 1000 items in the cache
  expires: 9001   // evict items that are older than 9001 ms
});

// get value from cache, because 'test' isn't populated, run the populate function
cache.get('test', function(err, result) {
  if (err) return console.error(err);
  return console.log(result);
});

// listen for any evictions
cache.on('evict', function(evict) {
  console.log(evict.key);   // the key of the item being evicted
  console.log(evict.value); // the value of key that is being removed from the cache
  console.log(evict.reason); // the reason the eviction occured (manual, capacity, expired)
});

// can also listen for specific types of evictions
cache.on('evict:manual', function(evict) {
  console.log(evict.key);
});

cache.evict('test');
```

Performance
===========

**get#hit** O(1)  
**get#miss** O(1) + O(populate)  
**evict** O(1)  
**expire** O(1)  