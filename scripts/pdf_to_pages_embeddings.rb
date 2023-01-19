require 'dotenv'
require 'ruby/openai'
require 'csv'
require 'pdf-reader'
require 'optparse'
require 'pycall/import'
include PyCall::Import
require 'pandas'
require 'daru'

# Use load_env to trace the path of .env:
Dotenv.load('.env')

$client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])

COMPLETIONS_MODEL = 'text-davinci-003'

MODEL_NAME = 'curie'

DOC_EMBEDDINGS_MODEL = "text-search-#{MODEL_NAME}-doc-001"

PyCall.pyfrom('transformers', import: 'GPT2TokenizerFast')
$tokenizer = PyCall::GPT2TokenizerFast.from_pretrained('gpt2')

def count_tokens(text)
  # """count the number of tokens in a string"""
  $tokenizer.encode(text).length
end

def extract_pages(page_text, index)
  # """
  # Extract the text from the page
  # """
  return [] if page_text.empty?

  content = page_text.split.join(' ')
  ["Page #{index}", content, count_tokens(content) + 4]
end

filename = 'placeholder.pdf'
OptionParser.new do |opt|
  opt.on('--pdf PDF') { |o| filename = o }
end.parse!

reader = PDF::Reader.new(filename)
res = []
i = 1
reader.pages.each do |page|
  extract = extract_pages(page.text, i)
  res << extract unless extract.empty?
  i += 1
end

puts 'pages extracted'

df = Daru::DataFrame.new(res)
df = df.transpose
df.vectors = Daru::Index.new(%i[title content tokens])

df = df.where(df[:tokens] < 2046)

# added because of ruby 3/2 incompatibility with positional arguments
def dataframe_write_csv(dataframe, path, opts = {})
  options = {
    converters: :numeric
  }.merge(opts)

  writer = ::CSV.open(path, 'w', **options)
  writer << dataframe.vectors.to_a unless options[:headers] == false

  dataframe.each_row do |row|
    writer << if options[:convert_comma]
                row.map { |v| v.to_s.tr('.', ',') }
              else
                row.to_a
              end
  end

  writer.close
end

dataframe_write_csv(df, "#{filename}.pages.csv")

$count = 1

def get_embedding(text, model)
  # add sleep so we don't exceed the openai api rate limit
  sleep(2)
  puts "#{$count}th request"
  result = $client.embeddings(parameters: { model:, input: text })
  $count += 1
  result['data'][0]['embedding']
end

def get_doc_embedding(text)
  get_embedding(text, DOC_EMBEDDINGS_MODEL)
end

def compute_doc_embeddings(_df)
  # Create an embedding for each row in the dataframe using the OpenAI Embeddings API.
  # Return a dictionary that maps between each embedding vector and the index of the row that it corresponds to.
  content_pos = 1
  _df.map_rows { |item| get_doc_embedding(item[content_pos]) }
end

# # # CSV with exactly these named columns:
# # # "title", "0", "1", ... up to the length of the embedding vectors.

doc_embeddings = compute_doc_embeddings(df)

CSV.open("#{filename}.embeddings.csv", 'w') do |csv|
  csv << ['title'] + (0..4095).to_a
  doc_embeddings.each_with_index do |data, idx|
    csv << ["Page #{idx + 1}"] + data
  end
end
