var Goldfish = require('../');

describe('#get', function() {
  it('should allow unpopulated key to be requested many times at once and return all of them once populated', function(done) {
    var cache
      , count = 0
      , num = 9001
      , i
      , callback
      ;
    
    cache = new Goldfish({
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

  it('should call populate only once when the same value is being fetched', function(done) {
    var cache
      , populateCount = 0
      ;

    cache = new Goldfish({
      populate: function(key, cb) {
        ++populateCount;
        setTimeout(function() {
          cb(null, key);
        }, 10);
      }
    });

    cache.get('test', function() {});
    cache.get('test', function(err, value) {
      if (populateCount === 1) return done();
      return done(new Error('expected populateCount to be 1'));
    });
  });

  it('should return an error', function(done) {
    var cache = new Goldfish({
      populate: function(key, cb) {
        cb('error');
      }
    });

    cache.get('test', function(err, value) {
      if (err == 'error') return done();
      done('should have gotten an error');
    });
  });
});

describe('#expires', function() {
  it('should expire a value after 10ms', function(done) {
    var cache = new Goldfish({
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

    cache = new Goldfish({
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