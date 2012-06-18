var goldfish = require('../');

describe('#get', function() {
  it('should allow unpopulated key to be requested many times at once and return all of them once populated', function(done) {
    var cache
      , count = 0
      , num = 9001
      , i
      , callback
      ;
    
    cache = goldfish.createGoldfish({
      populate: function(key, cb) {
        setTimeout(function() {
          cb(null, key);
        }, 10);
      }
    });

    callback = function(err, value) {
      if(value !== 'test') return;
      if(++count === num) done();
    }

    for(i = 0; i < num; ++i) {
      cache.get('test', callback);
    }
  });
});

describe('#expires', function() {
  it('should expire a value after 10ms', function(done) {
    var cache = goldfish.createGoldfish({
      populate: function(key, cb) {
        cb(null, key);
      },
      expires: 10,
      cleanup: 1
    });

    cache.on('evict', function() {
      done();
    });
    cache.get('test', function() {});
  });

  it('should evict multiple', function(done) {
    var cache
      , i
      , count = 0
      , num = 200
      ;

    cache = goldfish.createGoldfish({
      populate: function(key, cb) {
        cb(null, key);
      },
      expires: 10,
      cleanup: 1
    });

    cache.on('evict', function() {
      if(++count === num) done();
    });

    for(i=0; i<num; ++i) {
      cache.get('' + i, function() {});
    }
  })
});