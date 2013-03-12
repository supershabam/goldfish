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
jsosort = require "jsosort"
NULL = null
exports = module.exports = class Goldfish extends EventEmitter
  constructor: (options)->
    throw new Error("must specify populate function") unless options?.populate and typeof options.populate is "function"
    @_populate = options.populate
    @_context = options?.context? then options.context else null
    @_expires = if options?.expires? then options.expires else Infinity
    @_remind = if options.?remind? then options.remind else false
    @_capacity = if options?.capacity? then options.capacity else Infinity
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
      return process.nextTick(cb.apply({}, [null].concat(result)))
    # are we already fetching that value?
    return @_queue[hash].push(cb) if @_isQueued(hash)
    # alright, let's go get the value
    @_queue[hash] = [cb]
    args.push (err, result...)->
      # only write result if we got one
      @_insert(hash, result) unless err
      functions = @_queue[hash][..]
      delete @_queue[hash]
      for fn in functions
        fn.apply(null, [err].concat(result))
    @_populate.apply(@_context, args)
  _hash: (args)=>

  _insert: (hash, result)=>
    entry =
      hash: hash
      result: result
      expires: moment() + @_expires
    @_evict(@_oldest, "capacity") while @_size >= @_capacity
    @_cache[hash] = entry
    @_size += 1
  _refresh: (hash)=>
    entry = @_cache[hash]
    @_pullEntry(entry)
    @_pushEntry(entry)
    entry.expires = @_expires + moment().valueOf()
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