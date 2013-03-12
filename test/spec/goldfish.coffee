Goldfish = require "#{LIB_ROOT}/goldfish"
describe "goldfish", ->
  clock = null
  afterEach (done)->  
    clock.restore() if typeof clock is "function"
    done()
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
    populate = (arg1, arg2, cb)->
      return cb(null, arg2, arg1)
    cache = new Goldfish({populate: populate, capacity: 2})
    cache.on "evict", (entry)->
      expect(entry.args).to.eql ["arg1", "arg2"]
      expect(entry.result).to.eql ["arg2", "arg1"]
      expect(entry.expires).to.eql Infinity
      expect(getCount).to.equal 3
    getCount = 0
    cache.get "arg1", "arg2", (err, result1, result2)->
      expect(err).to.not.be.ok
      expect(result1).to.equal "arg2"
      expect(result2).to.equal "arg1"
      expect(getCount).to.equal 0
      getCount += 1
      # use cached result, no increase in capacity
      cache.get "arg1", "arg2", (err, result1, result2)->
        expect(err).to.not.be.ok
        expect(result1).to.equal "arg2"
        expect(result2).to.equal "arg1"
        expect(getCount).to.equal 1
        getCount += 1
        cache.get "one", "two", (err, result1, result2)->
          expect(err).to.not.be.ok
          expect(result1).to.equal "two"
          expect(result2).to.equal "one"
          expect(getCount).to.equal 2
          getCount += 1          
          cache.get "new", "entry", (err, result1, result2)->
            expect(err).to.not.be.ok
            expect(result1).to.equal "entry"
            expect(result2).to.equal "new"
            expect(getCount).to.equal 3
            done()

