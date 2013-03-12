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
      expect(arg3).to.eqaul "arg3"
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
    populateRunCount = 0
    callbackCount = 0
    populate = (key, cb)->
      populateRunCount += 1
      setTimeout(cb.bind(null, null, key), 1000)
    at500 = ->
      expect(populateRunCount).to.equal 0
    cache = new Goldfish({populate: populate})
    cache.get "key1", (err, value)->
      callbackCount += 1
      expect(err).to.not.be.ok
      expect(value).to.equal "key1"
      expect(populateRunCount).to.eqaul 1
    cache.get "key1", (err, value)->
      callbackCount += 1
      expect(err).to.not.be.ok
      expect(value).to.equal "key1"
      expect(populateRunCount).to.eqaul 1
    at200 = ->
      expect(cache._queue(cache._hash(["key1"]))).to.have.length 2
      cache.get "key2", (err, value)->
        callbackCount += 1
        expect(err).to.not.be.ok
        expect(value).to.equal "key2"
        expect(populateRunCount).to.eqaul 2
        expect(callbackCount).to.eqaul 3
        done()