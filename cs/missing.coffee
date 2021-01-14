# Generates all possible mnemonic phrases, given a partial mnemonic phrase.
#
# Command syntax
#
#   missing [--language <language>] [--index <list>|--end|--any] [--count <N>] <mnemonic phrase>
#
# Options
#
#   --any, -a       Signifies that the missing words in the phrase can be at any location. (optional)
#   --count, -n     Total number of words in the mnemonic phrase. (default is a multiple of 3 and depends on how many
#                   are known)
#   --end, -e       Signifies that the last words in phrase are missing. This option is overridden by --any and
#                   --index. (default)
#   --indexes, -i   List of the possible locations of the missing words. The first location is 1. Use - to end the
#                   list if it is not followed by another option. This option overrides --end and --any (optional)
#   --json, -j      Outputs the possible mnemonics in json format. (optional)
#   --language, -l  The wordlist to be used. Currently, only *english* is supported and it is the default. (optional)
#
# Examples:
#
# All but the last words of a 12-word mnemonic are known:
#     missing crisp three spoil enhance dial client moment melt parade aisle
#
# Missing words could be anywhere in the mnemonic:
#     missing --any crisp three enhance dial client melt parade aisle analyst case
#
# Words 1, 3, and 7 are missing:
#     missing --index 1 3 7 -- three enhance dial client melt parade aisle analyst case
#
# A count must be specified because only 8 of 12 words are listed:
#     missing --end --count 12 crisp three spoil enhance dial client moment melt parade

yargs = require 'yargs'
Crypto = require 'crypto'
bip39 = require './bip39'

unique = (array) ->
  itemized = {}
  itemized[e] = e for e in array
  (value for key, value of itemized)

combinationsOf = (array, n = array.length) ->
  result = []
  recurse = (c, remainder, n) ->
    if n > 0
      for i in [0..remainder.length - n]
        recurse c.concat([remainder[i]]), remainder[i + 1..], n - 1
    else
      result.push c
    return
  recurse [], array, n
  result

generateTemplate = (known, indexes, count) ->
  # Note: indexes are 1..count
  template = []
  j = 0
  k = 0
  for i in [1..count]
    if i == indexes[j]
      template.push null
      ++j
    else
      template.push known[k]
      ++k
  template

enumerate = (template, indexes, wordlist, cb) ->
  # Note: indexes are 1..count
  mnemonic = template[..]
  recurse = (remainingIndexes) ->
    for w in wordlist
      mnemonic[remainingIndexes[0] - 1] = w
      if remainingIndexes.length > 1
        recurse remainingIndexes[1..]
      else
#        console.log "Trying: #{mnemonic}"
        cb mnemonic
    return
  recurse indexes
  return



args = yargs
  .usage '$0 <mnemonic..>', 'Generates all possible mnemonic phrases, given a partial mnemonic phrase.'
  .help()
  .version()
  .option 'any', {
    type: 'boolean'
    alias: 'a'
    conflicts: ['end', 'indexes']
    describe: 'Signifies that the missing words can be at any location in the phrase.'
  }
  .option 'count', {
    type: 'number'
    alias: 'n'
    describe: 'Total number of words in the mnemonic phrase.'
  }
  .option 'end', {
    type: 'boolean'
    alias: 'e'
    conflicts: ['any', 'indexes']
    describe: 'Signifies that the missing words are at the end of the phrase.'
  }
  .option 'indexes', {
    type: 'array'
    alias: 'i'
    conflicts: ['any', 'end']
    implies: 'count'
    describe: 'List of the possible locations of the missing words. The first location is 1. Use - to end a
               list not followed by another option.'
  }
  .option 'json', {
    type: 'boolean'
    alias: 'j'
    default: false
    describe: 'The phrases are listed in JSON format.'
  }
  .option 'language', {
    type: 'string'
    choices: ['english']
    default: 'english'
    alias: 'l'
    describe: 'The wordlist to be used. Currently, only english is supported. (optional)'
  }
  .option 'v', {
    type: 'count'
    alias: 'verbose'
    describe: 'Additional information is displayed.'
  }
  .example [
    [
      '$0 crisp three spoil enhance dial client moment melt parade aisle'
      'All but the last two words of a 12-word mnemonic are known.'
    ]
    [
      '$0 --any crisp three enhance dial client melt parade aisle analyst case'
      'Two missing words could be anywhere.'
    ]
    [
      '$0 --indexes 1 3 7 - crisp three enhance dial client melt parade aisle analyst case'
      'The two missing words could be at locations 1, 3, or 7.'
    ]
    [
      '$0 --count 12 crisp three spoil enhance dial client moment melt'
      'A count should be specified because eight known words implies a 9-word phrase.'
    ]
  ]
  .check (argv) ->
    if argv.count?
      if argv.count <= 0 or argv.count % 3 != 0
        throw new Error "'count' must be a positive multiple of 3"
      if argv.count <= argv.mnemonic.length
        throw new Error "'count' must be greater than the number of known words"
    if argv.indexes?
      if argv.indexes.length > argv.count
        throw new Error "'count' must be greater than or equal to the number of indexes"
      for i in argv.indexes
        if i < 1 or i > argv.count
          throw new Error "Invalid index #{i}"
    return true
  .argv

#console.log 'args=', JSON.stringify(args)

# Default count is the next multiple of 3 after the number of known words plus 1 unknown
count = if args.count? then args.count else Math.ceil((args.mnemonic.length + 1) / 3) * 3

# Generate the index combinations (note the first index is 1)
if args.any
  indexes = [1..count]
else if args.indexes?
  indexes = unique args.indexes #de-dup and sort
else # Otherwise, assume missing words are at the end (--end option)
  indexes = [args.mnemonic.length + 1..count]

n = count - args.mnemonic.length
indexCombinations = combinationsOf indexes, n

# Look for all possibilities for each combination of indexes
possibilities = []

for c in indexCombinations
  template = generateTemplate args.mnemonic, c, count
  process.stdout.write "Trying '" + bip39.stringify(template) + "' \n" if args.verbose > 0

  # Check each enumeration
  enumerate template, c, bip39.wordlists[args.language], (mnemonic) ->
    [ok, result] = bip39.decode mnemonic, args.language
    if ok
      possibilities.push bip39.stringify(mnemonic)
    true

# Print the results
if args.json
  process.stdout.write JSON.stringify(possibilities)
else
  process.stdout.write "#{possibilities.length} possibilities:\n" if args.verbose > 0
  process.stdout.write(p + '\n') for p in possibilities

