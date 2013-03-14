##
# Goldfish - the cache the forgets
# Copyright(c) 2013 Ian Hansen <ian@supershabam.com>
# MIT Licensed
#          _,           _,
#        .' (        .-' /
#      _/..._'.    .'   /
#  .-'`      ` '-./  _.'
# ( o)           ;= <_
#  '-.,\\__ __.-;`\   '.
#       \) |`\ \)  '.   \
#          \_/   jgs '-._\
#                        `
{EventEmitter} = require "events"
jsosort = require "jsosort"
moment = require "moment"
NULL = null
exports = module.exports = class Goldfish extends EventEmitter
  constructor: (options)->
    throw new Error("must specify populate function") unless options?.populate and typeof options.populate is "function"
    @_populate = options.populate
    @_context = if options?.context? then options.context else null
    @_expires = if options?.expires? then options.expires else Infinity
    @_remind = if options?.remind? then options.remind else false
    @_capacity = if options?.capacity? then options.capacity else Infinity
    throw new Error("must have at least 0 capacity") if @_capacity < 0
    @_garbageInterval = if options?.garbageInterval? then options.garbageInterval else 60000
    @_cache = Object.create(null)
    @_queue = Object.create(null)
    @_newest = NULL
    @_oldest = NULL
    @_size = 0
    @_cleaner = setInterval(@_clean, @_garbageInterval)
  ##
  # args Call with the number of arguments that should be passed to populate
  # cb Function
  get: (args..., cb)=>
    now = moment().valueOf()
    hash = @_hash(args)
    # before reading from local cache, expire this hash if it's too old
    @_expire(hash) if @_has(hash) and @_cache[hash].expires < now
    # commence cache retreival
    if @_has(hash)
      # refresh the key if we're in remind mode
      @_refresh(hash) if @_remind
      # do callback on next cpu event (allow caller to operate truly async)
      result = @_cache[hash].result
      return process.nextTick ->
        cb.apply({}, [null].concat(result))
    # are we already fetching that value?
    return @_queue[hash].push(cb) if @_isQueued(hash)
    # alright, let's go get the value
    @_queue[hash] = [cb]
    callback = (err, result...)=>
      # only write result if we got one
      @_insert(hash, args, result) unless err
      functions = @_queue[hash][..]
      delete @_queue[hash]
      for fn in functions
        fn.apply(null, [err].concat(result))
    @_populate.apply(@_context, args.concat([callback]))
  _clean: =>
  _evict: (entry)=>
    if @_has(entry.hash)
      @_pullEntry(entry)
      delete @_cache[entry.hash]
      @emit("evict", entry)
  _has: (hash)=>
    return Object.prototype.hasOwnProperty.call(@_cache, hash)
  _hash: (args)=>
    result = []
    for arg in args
      if Object.prototype.toString.call(arg) is "[object Object]"
        arg = jsosort(arg)
      result.push(arg)
    return JSON.stringify(result)
  _insert: (hash, args, result)=>
    entry =
      hash: hash
      args: args
      result: result
      expires: moment() + @_expires
    @_size += 1
    while @_size > @_capacity
      @_evict(@_oldest)
      @_size -= 1
    @_pushEntry(entry)
    @_cache[hash] = entry
  _isQueued: (hash)=>
    return Object.hasOwnProperty.call(@_queue, hash)
  _pullEntry: (entry)=>
    if entry.older isnt NULL and entry.newer isnt NULL
      entry.older.newer = entry.newer
      entry.newer.older = entry.older
    if @_oldest is entry and @_newest is entry
      @_oldest = NULL
      @_newest = NULL
    if @_oldest is entry
      @_oldest = entry.newer
      entry.newer.older = NULL
    if @_newest is entry
      @_oldest = entry.older
      entry.older.newer = NULL
  _pushEntry: (entry)=>
    if @_newest is NULL
      @_newest = entry
      @_oldest = entry
      entry.newer = NULL
      entry.older = NULL
    else
      @_newest.newer = entry
      entry.older = @_newest
      entry.newer = NULL
      @_newest = entry
  _refresh: (hash)=>
    entry = @_cache[hash]
    @_pullEntry(entry)
    @_pushEntry(entry)
    entry.expires = @_expires + moment().valueOf()