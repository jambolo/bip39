# Command syntax
# 
#   share sss <M> <N> [--language english] <mnemonic phrase>
#   share xor <N> [--language english] <mnemonic phrase>
# 
# Methods
# 
#   sss   Shamir Secret Sharing
#   xor   XOR
# 
# Sharing Parameters
# 
#   M     Minimum shares necessary to recreate the original. This number must be less than or equal to N.
#   N     Number of shares
# 
# Options
# 
#   --language, -l    The wordlist to be used. Currently, only english is supported and it is the default. (optional)
#   --json
# 
# One method of sharing is a secret is Shamir Secret Sharing (SSS). A description can be found here:
# https://en.wikipedia.org/wiki/Shamir%27s_Secret_Sharing. Using SSS, you can generate N shares, of which M are
# required in order to recreate the original mnemonic.
# 
# Another method for for sharing a secret is called the XOR method. This implementation is based on the implementation
# described here: https://github.com/mmgen/mmgen/wiki/XOR-Seed-Splitting:-Theory-and-Practice. In this scheme, all
# shares are required, so M is N.
# 
# This program decodes the mnemonic and generates the shares, which are then re-encoded. Note that while the encoded
# share phrases have the standard BIP-39 error-detection, there is no way to ensure that the value recreated by joining
# shares matches the original value.

yargs = require "yargs"
Base58 = require "base-58"
Crypto = require "crypto"
wordlists = require "./wordlists"

decode = (mnemonic, language) ->
  # Get the indexes of the words in the input mnemonic phrase
  indexes = []
  for m in mnemonic
    i = wordlists[language].indexOf m
    if i == -1
      console.error "'#{args.$0}: #{m}' is not in the '#{language}' word list."
      process.exit 1
    indexes.push i

  # Concatenate the indexes
  nbytes = Math.floor (indexes.length * 11 + 7) / 8
  checked = Buffer.alloc nbytes, 0
  b = -8
  acc = 0
  j = 0
  for i in [0...nbytes]
    if b < 0
      acc = acc << 11
      if j < indexes.length
        acc += indexes[j++]
      b += 11
    checked[i] = acc >> b
    acc = acc % (1 << b)
    b -= 8

  # Split the data and the checksum
  nCheckBits = indexes.length / 3
  nDataBytes = nCheckBits * 4
  padded = checked.slice 0, nDataBytes
  checksum = checked.slice nDataBytes

  # Compare the checksum to the first nCheckBits of the SHA-256 of the padded data. To simplify the comparison, the bits
  # in the sha256 result that correspond to padding in the checksum are forced to 0 so only the relevant bits are
  # compared.
  expected = sha256 padded
  if nCheckBits % 8 != 0
    expected[checksum.length-1] &= ~((1 << (8 - (nCheckBits % 8))) - 1)

  if checksum.compare(expected, 0, checksum.length) != 0
    console.error "#{args.$0}: The mnemonic phrase's checksum does not match. The phrase is corrupted."
    process.exit 1

  return padded

# Returns the SHA-256 hash of the input
sha256 = (input) ->
  hash = Crypto.createHash "sha256"
  hash.update input
  return hash.digest()

# Returns the BIP-39 encode of the input
encode = (share, language) ->
  nWords = share.length / 4 * 3

  # Append the checksum
  checked = Buffer.concat [share, sha256(share)] # Note extra is ignored

  # Compute the word indexes
  indexes = new Array nWords
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

  # Get the words and save the phrase
  return (wordlists[language][i] for i in indexes)

# Creates n shares of the input using the XOR method
xor = (input, n) ->
    size = input.length

    # The first n-1 shares are just random
    shares = (Crypto.randomBytes size for i in [0...n-1])

    # The last share is the input XORed with all the other shares
    last = Buffer.from input
    for share in shares
      for i in [0...size]
        last[i] ^= share[i]
    shares.push last

    return shares

sss = (input, m, n) ->
  console.error "Shamir Secret Sharing is not yet implemented."
  process.exit 1
  return

# Configure the command line processing
args = yargs
  .usage "$0 <method> <args..>"
  .command "sss <M> <N> <mnemonic..>", "Use Shamir Secret Sharing to share a mnemonic phrase", (yargs) ->
    yargs
      .positional "M", {
        type: "number"
        describe: "Threshold"
      }
      .positional "N", {
        type: "number"
        describe: "Number of shares"
      }
      .positional "mnemonic", {
        type: "string"
        describe: "The mnemonic phrase"
      }
  .command "xor <N> <mnemonic..>", "Use XOR to share a mnemonic phrase", (yargs) ->
    yargs
      .positional "N", {
        type: "number"
        describe: "Number of shares"
      }
      .positional "mnemonic", {
        type: "string"
        describe: "The mnemonic phrase"
      }
  .help()
  .version()
  .option "language", {
    type: "string"
    choices: ["english"]
    default: "english"
    alias: "l"
    describe: "The wordlist to be used for validation. Currently, only english is supported. (optional)"
  }
  .option "json", {
    type: "boolean"
    default: false
    alias: "j"
    describe: "The words are listed in JSON format."
  }
  .check (argv) ->
    if argv.mnemonic.length < 3 or argv.mnemonic.length > 768 or argv.mnemonic.length % 3 != 0
      throw new Error "The number of words must be a multiple of and 3 between 3 and 768."
    if argv.N < 2
      throw new Error "The number of shares, N, must be at least 2."
    if argv.M? and (argv.M < 1 or argv.M > argv.N)
      throw new Error "The threshold value, M, must be at least 1 and cannot be greater than the number of shares, N."
    return true
  .argv

decoded = decode args.mnemonic, args.language

# Generate the shares
switch args._[0]
  when "sss" then shares = sss decoded, args.M, args.N
  when "xor" then shares = xor decoded, args.N

# BIP-39 encode the shares
phrases = (encode share, args.language for share in shares)

# Output

if args.json
  process.stdout.write JSON.stringify(phrases)
else
  for phrase in phrases
    process.stdout.write w + " " for w in phrase[0...-1]
    process.stdout.write phrase[phrase.length-1] + "\n"
