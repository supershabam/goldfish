Goldfish
========

Goldfish - the forgetful in-memory cache

```javascript
//          _,           _,
//        .' (        .-' /
//      _/..._'.    .'   /
//  .-'`      ` '-./  _.'
// ( o)           ;= <_
//  '-.,\\__ __.-;`\   '.
//       \) |`\ \)  '.   \
//          \_/   jgs '-._\
//                        `
```

[![Build Status](https://secure.travis-ci.org/supershabam/goldfish.png?branch=master)](http://travis-ci.org/supershabam/goldfish)

[![endorse](http://api.coderwall.com/supershabam/endorsecount.png)](http://coderwall.com/supershabam)

Options
=======
```javascript
Goldfish({
  populate: // fn(arg1, arg2, ..., cb)
  expires: // (optional) Integer - miliseconds before a cache item is expired (default = Infinity)
  remind: // (optional) Boolean - refresh expire time on fetch (default = false)
  capacity: // (optional) Integer - max number of items to have in the cache (default = Infinity)
});
```

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
cache.on('evict', function(entry) {
  console.log(entry.args); // Array - the args passed to populate resulting in this entry
  console.log(evict.result); // Array - the results from populate
});
// clear the cache
cache.clear();
```

Performance
===========

**get#hit** O(1)  
**get#miss** O(1) + Populate()
**clear** O(n)

Changelog
=========

0.1.0
-----

Complete disregard for the previous api. Don't blindly update.
Smaller, simpler api.

