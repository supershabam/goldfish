async = require "async"
Goldfish = require "#{LIB_ROOT}/goldfish"
describe "goldfish", ->
  clock = null
  afterEach ->
    clock.restore() if clock
  it "should run populate with variable args and variable response", (done)->
    hasRunPopulate = false
    populate = (arg1, arg2, arg3, cb)->
      hasRunPopulate = true
      expect(arg1).to.equal "arg1"
      expect(arg2).to.equal "arg2"
      expect(arg3).to.equal "arg3"
      expect(typeof cb).to.equal "function"
      cb(null, "1", "2", "3") 
    cache = new Goldfish({populate: populate})
    cache.get "arg1", "arg2", "arg3", (err, result1, result2, result3)->
      expect(err).to.not.be.ok
      expect(result1).to.equal "1"
      expect(result2).to.equal "2"
      expect(result3).to.equal "3"
      done()
  it "should queue up populate", (done)->
    clock = sinon.useFakeTimers()
    prePopulate = 0
    postPopulate = 0
    callbackCount = 0
    populate = (key, cb)->
      prePopulate += 1
      fn = ->
        postPopulate += 1
        cb(null, key)
      setTimeout(fn, 1000)
    at500 = ->
      expect(prePopulate).to.equal 2
      expect(postPopulate).to.equal 0
    cache = new Goldfish({populate: populate})
    cache.get "key1", (err, value)->
      callbackCount += 1
      expect(err).to.not.be.ok
      expect(value).to.equal "key1"
      expect(prePopulate).to.equal 2
      expect(postPopulate).to.equal 1
    cache.get "key1", (err, value)->
      callbackCount += 1
      expect(err).to.not.be.ok
      expect(value).to.equal "key1"
      expect(prePopulate).to.equal 2
      expect(postPopulate).to.equal 1
    at200 = ->
      expect(cache._queue[cache._hash(["key1"])]).to.have.length 2
      cache.get "key2", (err, value)->
        callbackCount += 1
        expect(err).to.not.be.ok
        expect(value).to.equal "key2"
        expect(prePopulate).to.equal 2
        expect(postPopulate).to.equal 2
        expect(callbackCount).to.equal 3
        done()
    setTimeout(at200, 200)
    setTimeout(at500, 500)
    clock.tick(1500)
  it "should evict on over capacity", (done)->
    populate = (arg, cb)->
      return cb(null, arg)
    cache = new Goldfish({populate: populate, capacity: 2})
    evictHasBeenCalled = false
    cache.on "evict", (entry)->
      evictHasBeenCalled = true
      expect(entry.args).to.eql ["1"]
      expect(entry.result).to.eql ["1"]
      expect(entry.expires).to.eql Infinity
      expect(getCount).to.equal 3
    getCount = 0
    cache.get "1", (err, result)->
      expect(err).to.not.be.ok
      expect(result).to.equal "1"
      expect(getCount).to.equal 0
      getCount += 1
      # use cached result, no increase in capacity
      cache.get "1", (err, result)->
        expect(err).to.not.be.ok
        expect(result).to.equal "1"
        expect(getCount).to.equal 1
        getCount += 1
        cache.get "2", (err, result)->
          expect(err).to.not.be.ok
          expect(result).to.equal "2"
          expect(getCount).to.equal 2
          getCount += 1          
          cache.get "3", (err, result)->
            expect(err).to.not.be.ok
            expect(result).to.equal "3"
            expect(getCount).to.equal 3
            expect(evictHasBeenCalled).to.be.ok
            done()
  it "should return errors, and not cache them", (done)->
    populate = (arg, cb)->
      return cb(new Error("OMG"))
    cache = new Goldfish({populate: populate})
    cache.get "test", (err, value)->
      expect(err).to.be.ok
      expect(cache._size).to.equal 0
      done()
  it "should expire after 10ms even if I get the key just before", (done)->
    clock = sinon.useFakeTimers()
    populate = (arg, cb)->
      return cb(null, arg)
    cache = new Goldfish({populate: populate, expires: 10000})
    cache.get "key", (err, value)->
      expect(err).to.not.be.ok
      expect(value).to.equal "key"
      clock.tick(9000)
      cache.get "key", (err, value)->
        expect(err).to.not.be.ok
        expect(value).to.equal "key"
        cache.on "evict", (entry)->
          expect(entry.result).to.eql ["key"]
          expect(cache._size).to.equal 0
        clock.tick(1050)
        cache.get "key", (err, value)->
          expect(err).to.not.be.ok 
          expect(value).to.equal "key"
          done()
  it "should refresh keys after I fetch them", (done)->
    clock = sinon.useFakeTimers()
    shouldExpire = false
    populate = (arg, cb)->
      return cb(null, arg)
    cache = new Goldfish({populate: populate, expires: 10000, remind: true})
    cache.on "evict", (entry)->
      expect(shouldExpire).to.be.ok
      done()
    cache.get "key", (err, value)->
      expect(value).to.equal "key"
      clock.tick(9000)
      cache.get "key", (err, value)->
        expect(value).to.equal "key"
        clock.tick(9000)
        cache.get "key", (err, value)->
          expect(value).to.equal "key"
          shouldExpire = true
          clock.tick(10001)
          cache.get "key", (err, value)->
  it "should clear cache", (done)->
    populate = (arg, cb)->
      return cb(null, arg)
    cache = new Goldfish({populate: populate})
    work = []
    for i in [0...20]
      do (i)->
        work.push (callback)->
          cache.get i, callback
    async.parallel work, (err)->
      return done(err) if err
      count = 0
      cache.on "evict", (entry)->
        count += 1
      cache.clear()
      expect(count).to.equal 20
      done()
  it "should call callback only once", (done)->
    count = 0
    clock = sinon.useFakeTimers()
    populate = (arg, cb)->
      setTimeout(cb.bind(null, new Error("lulz")), 1000)
    cache = new Goldfish({populate: populate})
    setTimeout(done, 2000)
    cache.get "test", (err, value)->
      count += 1
      expect(count).to.equal 1
      expect(err).to.be.ok
      clock.tick(1000)
    clock.tick(1000)