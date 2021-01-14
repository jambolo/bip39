wordlists = require './wordlists'
Crypto = require 'crypto'

sha256 = (input) ->
  hash = Crypto.createHash 'sha256'
  hash.update input
  hash.digest()

# Returns the decoded BIP-39 mnemonic or an error message
decode = (mnemonic, language) ->
  # Get the indexes of the words
  indexes = []
  for m in mnemonic
    i = wordlists[language].indexOf m
    return [false, "#{m}' is not in the '#{language}' word list."] if i == -1
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
  data = checked.slice 0, nDataBytes
  checksum = checked.slice nDataBytes

  # Compare the checksum to the first nCheckBits of the SHA-256 of the padded data. To simplify the comparison, the
  # bits in the sha256 result that correspond to padding in the checksum are forced to 0 so only the relevant bits
  # are compared.
  expected = sha256 data
  if nCheckBits % 8 != 0
    expected[checksum.length - 1] &= ~((1 << (8 - (nCheckBits % 8))) - 1)

  if checksum.compare(expected, 0, checksum.length) != 0
    return [false, "The mnemonic phrase's checksum does not match. The phrase is corrupted."]

  [true, data]

# Returns the BIP-39 encode of the input
encode = (data, language) ->
  nWords = data.length / 4 * 3

  # Append the checksum
  checked = Buffer.concat [data, sha256(data)] # Note extra hash bits will ignored

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
  (wordlists[language][i] for i in indexes)

stringify = (words) ->
  text = ''
  for i in [0...words.length - 1]
    text += if words[i] then words[i] else '?'
    text += ' '
  text += if words[words.length - 1] then words[words.length - 1] else '?'
  text

module.exports = {
  decode
  encode
  stringify
}
