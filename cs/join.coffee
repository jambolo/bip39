# Command syntax
# 
#   join [--language <language>] [--json] (sss|xor)
# 
# Methods (one must be specified)
# 
#   sss   Shamir's Secret Sharing
#   xor   XOR
# 
# Options
# 
#   --language, -l    The wordlist to be used. Currently, only *english* is supported and it is the default.
#                     (optional)
#   --json, -j        Outputs the words in json format. (optional)
# 
# The shares are read from stdin, one per line and joined using SSS or the XOR method. Note that while the share
# phrases are validated according to BIP-39, there is no way to ensure that the value recreated by joining
# shares matches the original value.

yargs = require "yargs"
Base58 = require "base-58"
Crypto = require "crypto"
readline = require "readline"
wordlists = require "./wordlists"

class Mod
  @add: (a, b, m) -> (a + b) % m

  @sub: (a, b, m) -> (a + (m - b)) % m

  @neg: (a, m) -> (m - a) % m

  @mul: (a, b, m) -> (a * b) % m

  @div: (a, b, m) -> (a * @inv(b, m)) % m

  # https://en.wikipedia.org/wiki/Modular_multiplicative_inverse#Extended_Euclidean_algorithm
  @inv: (a, m) ->
    [ gcd, x, y ] = @xgcd a, m
    return (m + x) % m

  # https://en.wikipedia.org/wiki/Extended_Euclidean_algorithm
  @xgcd: (a, b) ->
    x = 1n
    x1 = 0n
    y = 0n
    y1 = 1n
    while b > 0
      q = a / b
      [ a, b ] = [ b, a % b ]
      [ x, x1 ] = [ x1, x - q * x1 ]
      [ y, y1 ] = [ y1, y - q * y1 ]
    return [ a, x, y ]

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

# Joins shares using the XOR method
xor = (shares) ->
    joined = Buffer.from shares[0]
    for i in [1...shares.length]
      share = shares[i]
      joined[j] ^= share[j] for j in [0...joined.length]
    return joined

# https://en.wikipedia.org/wiki/Shamir%27s_Secret_Sharing
sss = (shares) ->
  p = 999999999989n # Biggest prime I could find. Must be 2^32-1 < p < 2^48 and must match share.coffee.

  L0 = (xs, ys) ->
    sum = 0n
    for j in [0...xs.length]
      product = 1n
      for m in [0...xs.length] when m isnt j
        product = Mod.mul(product, Mod.div(xs[m], Mod.sub(xs[m], xs[j], p), p), p)
      sum = Mod.add(sum, Mod.mul(ys[j], product, p), p)
    return sum

  nBlocks = shares[0].length / 8
  joined = Buffer.allocUnsafe nBlocks * 4
  for b in [0...nBlocks]
    xs = []
    ys = []
    for share in shares
      x = BigInt(share.readUInt16BE(b * 8 + 6))
      y = (BigInt(share.readUInt32BE(b * 8 + 0)) << 16n) + BigInt(share.readUInt16BE(b * 8 + 4))
      xs.push x
      ys.push y
    block = L0 xs, ys
    joined.writeUInt32BE Number(block), b * 4
  return joined

# Configure the command line processing
args = yargs
  .usage "$0 <method>", "Use Shamir's Secret Sharing or XOR methods to recreate the original mnemonic phrase from shares read from stdin", (yargs) ->
    yargs
      .positional "method", {
        type: "string"
        choices: ["sss", "xor"]
        describe: "Method"
      }
  .help()
  .version()
  .option "language", {
    type: "string"
    choices: ["english"]
    default: "english"
    alias: "l"
    describe: "The wordlist to be used. Currently, only english is supported. (optional)"
  }
  .option "json", {
    type: "boolean"
    default: false
    alias: "j"
    describe: "The words are listed in JSON format."
  }
  .argv

shares = []
rl = readline.createInterface { input: process.stdin }
rl.on 'line', (line) ->
  phrase = line.trim().split " "
  shares.push phrase

rl.on 'close', () ->
  decoded = (decode share, args.language for share in shares)

  # Generate the shares
  switch args.method
    when "sss" then joined = sss decoded
    when "xor" then joined = xor decoded

  # BIP-39 encode the joined shares
  words = encode joined, args.language

  # Output
  if args.json
    process.stdout.write JSON.stringify(words)
  else
    process.stdout.write w + " " for w in words[0...-1]
    process.stdout.write words[words.length-1]
