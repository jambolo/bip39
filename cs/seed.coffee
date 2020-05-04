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
      throw new Error("The number words in the mnemonic must be a multiple of 3.")
    return true
  .argv

# Validate the mnemonic words if requested
if args.validate
  for m in args.mnemonic
    if wordlists[args.language].indexOf(m) == -1
      console.error "#{args.$0}: '#{m}' is not in the '#{args.language}' word list."
      process.exit 1

# Create the "sentence" from the words
sentence = ""
sentence += w + " " for w in args.mnemonic[0...-1]
sentence += args.mnemonic[args.mnemonic.length-1]

# Generate the seed
seed = Crypto.pbkdf2Sync sentence, "mnemonic"+args.passphrase, 2048, 64, "sha512"

# Output the seed
process.stdout.write seed.toString("hex")
