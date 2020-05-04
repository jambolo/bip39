# Encodes a value using BIP 39. The size of the BIP-39 source must be a
# multiple of 32 bits. Here, it is padded with 0's, if necessary, to
# make the size a multiple of 32 bits.
#
# Command syntax:
# 
#   encode (hex|base58|base64) [--words <number>] [--strict] [--language english] [--json] <input>
# 
# Options:
# 
#   Format:
#       hex    - Input is a hex value
#       base58 - Input is an address or private key encoded using base-58
#       base64 - Input is a base-64 value
#
#   --words <number> - Number of words to be generated. The input is
#                      truncated or padded with 0's if it doesn't match
#                      the the specified value. If --strict is
#                      specified and the input doesn't match, the
#                      encode will fail.
# 
#   --strict - The length of the input must match the number of words
#              (if specified).
#
#   --language - The wordlist to use. Currently, only english is
#                supported and it is the default.
#
#   --json - Outputs the words in json format

yargs = require "yargs"
Base58 = require "base-58"
Crypto = require "crypto"
wordlists = require "./wordlists"

sha256 = (input) ->
  hash = Crypto.createHash "sha256"
  hash.update input
  return hash.digest()

pad = (input, words) ->
  total = if words? then words / 3 * 4 else input.length
  if total % 4 != 0
    total += 4 - total % 4
  if total == input.length
    padded = input
  else if total < input.length
    padded = input.slice 0, total
  else
    padded = Buffer.concat([input, Buffer.alloc(total - input.length, 0)])
  return padded

args = yargs
  .usage "$0 <format> <input>", "Encode a value using BIP 39", (yargs) ->
    yargs
      .positional "format", {
        type: "string"
        choices: ["hex", "base58", "base64"]
        describe: "Input format"
      }
      .positional "input", {
        type: "string"
        describe: "Input to encode"
      }
  .help()
  .version()
  .option "words", {
    type: "number"
    alias: "n"
    describe: "Number of words to be generated. The input is truncated or padded with 0's if it doesn't match
               the the specified value. The number of words must be a multiple of 3 and must be greater than 0.
               If --strict is specified and the input doesn't match, the encode will fail."
  }
  .option "strict", {
    type: "boolean"
    default: false
    alias: "s"
    describe: "The length of the input must match the number of words (if specified)."
  }
  .option "language", {
    type: "string"
    choices: ["english"]
    default: "english"
    alias: "l"
    describe: "The wordlist to use. Currently, only english is supported and it is the default."
  }
  .option "json", {
    type: "boolean"
    default: false
    alias: "j"
    describe: "The words are listed in JSON format."
  }
  .check (argv) ->
    if argv.words? and (argv.words < 3 or argv.words > 768 or argv.words % 3 != 0)
      throw new Error("The number of words must be a multiple of and 3 between 3 and 768.")
    return true
  .argv

# Convert the input to binary based on the type
switch args.format
  when "hex" then input = Buffer.from args.input, "hex"
  when "base58" then input = Base58.decode  args.input
  when "base64" then input = Buffer.from args.input, "base64"

# If strict, then make sure the sizes match
if args.strict and args.words? and input.length != args.words / 3 * 4
  console.error "#{args.$0}: The size of the input does not correspond exactly to the requested number of words."
  process.exit 1

# Pad (or truncate) if necessary or desired
padded = pad(input, args.words)
nWords = padded.length / 4 * 3

# Append the checksum
checked = Buffer.concat [padded, sha256(padded)] # Note extra is ignored

# Compute the word indexes
indexes = new Array(nWords)
b = -11
acc = 0
j = 0
for i in [0...nWords]
  while b < 0
    acc = (acc << 8) + checked[j++]
    b += 8
  indexes[i] = acc >> b
  acc = acc % (1 << b)
  b -= 11

# Get the words
words = (wordlists[args.language][indexes[i]] for i in [0...nWords])

# Output
if args.json
  process.stdout.write JSON.stringify(words)
else
  for w in words[0...-1]
    process.stdout.write w
    process.stdout.write " "
  process.stdout.write words[words.length-1]
