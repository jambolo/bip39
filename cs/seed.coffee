# Generates the seed from a mnemonic phrase
#
# Command syntax:
#
#   seed [--passphrase <passphrase>] [--validate] [--language english] <mnemonic phrase>
#
# Options:
#
#   --passphrase - Passphrase. (optional)
#   --validate   - If specified, the mnemonic phrase is validated (optional).
#   --language   - The wordlist to be used to validate the mnemonic phrase (optional).

yargs = require "yargs"
Crypto = require "crypto"
wordlists = require "./wordlists"

sha256 = (input) ->
  hash = Crypto.createHash "sha256"
  hash.update input
  return hash.digest()

validate = (mnemonic, language) ->
  # Get the indexes of the words
  indexes = []
  for m in mnemonic
    i = wordlists[language].indexOf m
    if i == -1
      console.error "#{args.$0}: '#{m}' is not in the '#{args.language}' word list."
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
  # in the sha256 result that correspond to padding in the checksum are forced to 0 and only the relevant bytes are
  # compared.
  expected = sha256 padded
  if nCheckBits % 8 != 0
    expected[checksum.length-1] &= ~((1 << (8 - (nCheckBits % 8))) - 1)

  if checksum.compare(expected, 0, checksum.length) != 0
    console.error "#{args.$0}: The mnemonic phrase's checksum does not match. The phrase is corrupted."
    process.exit 1

  return

args = yargs
  .usage "$0 <mnemonic..>", "Generates a BIP-39 seed."
  .help()
  .version()
  .option "passphrase", {
    type: "string"
    default: ""
    alias: "p"
    describe: "An passphrase used in generating the seed. (optional)"
  }
  .option "validate", {
    type: "boolean"
    alias: "v"
    default: false
    describe: "If included, the mnemonic phrase is validated."
  }
  .option "language", {
    type: "string"
    choices: ["english"]
    default: "english"
    alias: "l"
    describe: "The wordlist to be used for validation. Currently, only english is supported. (optional)"
  }
  .check (argv) ->
    if argv.validate and argv.mnemonic.length % 3 != 0
      throw new Error "The number words in the mnemonic must be a multiple of 3." 
    return true
  .argv

# Validate the mnemonic words if requested
validate args.mnemonic, args.language if args.validate

# Create the "sentence" from the words
sentence = ""
sentence += w + " " for w in args.mnemonic[0...-1]
sentence += args.mnemonic[args.mnemonic.length-1]

# Generate the seed
seed = Crypto.pbkdf2Sync sentence, "mnemonic"+args.passphrase, 2048, 64, "sha512"

# Output the seed
process.stdout.write seed.toString("hex")
