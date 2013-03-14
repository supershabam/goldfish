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
            

