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