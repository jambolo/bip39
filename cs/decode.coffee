# Decodes a mnemonic string back into the source value
#
# Command syntax:
#
#     decode (address|wif|base58|base64|hex) [--language english] <mnemonic phrase>
#
# Formats:
#
#   address - Decoded into a bitcoin address. 
#   wif     - Decoded into a WIF-formatted private key.
#   base58  - Output format is base-58.
#   base64  - Output format is base-64.
#   hex     - Output format is hex.
#
# Options:
#
#   --language - The wordlist to be used to validate the mnemonic phrase (optional).

yargs = require "yargs"
Base58 = require "base-58"
Crypto = require "crypto"
wordlists = require "./wordlists"

sha256 = (input) ->
  hash = Crypto.createHash "sha256"
  hash.update input
  return hash.digest()

args = yargs
  .usage "$0 <format> <mnemonic..>", "Decode a menmonic phrase using BIP-39", (yargs) ->
    yargs
      .positional "format", {
        type: "string"
        choices: ["address", "wif", "base58", "base64", "hex"]
        describe: "Output format"
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
  .check (argv) ->
    if argv.mnemonic.length < 3 or argv.mnemonic.length > 768 or argv.mnemonic.length % 3 != 0
      throw new Error("The number of words must be a multiple of and 3 between 3 and 768.")
    if argv.format is "address" and argv.mnemonic.length != 21
      throw new Error("A valid address must have 21 words.")
    if argv.format is "wif" and argv.mnemonic.length != 30
      throw new Error("A valid private key must have 30 words.")
    return true
  .argv

# Get the indexes of the words
indexes = []
for m in args.mnemonic
  i = wordlists[args.language].indexOf(m)
  if i == -1
    console.error "#{args.$0}: '#{m}' is not in the '#{args.language}' word list."
    process.exit 1
  indexes.push i

# Concatenate the indexes
nbytes = Math.floor((indexes.length * 11 + 7) / 8)
checked = Buffer.alloc(nbytes, 0)
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
padded = checked.slice(0, nDataBytes)
checksum = checked.slice(nDataBytes)

# Compare the checksum to the first nCheckBits of the SHA-256 of the padded data. To simplify the comparison, the bits
# in the sha256 result that correspond to padding in the checksum are forced to 0 and only the relevant bytes are
# compared.
expected = sha256(padded)
expected[checksum.length-1] &= ~((1 << (8 - (nCheckBits % 8))) - 1)

if checksum.compare(expected, 0, checksum.length) != 0
  console.error "The mnemonic phrase's checksum does not match. The phrase is corrupted."
  process.exit 1

# Generate the output
switch args.format
  when "address" then output = Base58.encode padded.slice(0, padded[padded.length-1])
  when "wif" then output = Base58.encode padded.slice(0, padded[padded.length-1])
  when "base58" then output = Base58.encode  padded
  when "base64" then output = padded.toString "base64"
  when "hex" then output = padded.toString "hex"

process.stdout.write output
