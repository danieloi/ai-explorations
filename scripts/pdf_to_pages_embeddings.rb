require 'dotenv'
require 'ruby/openai'
require 'csv'
require 'pdf-reader'
require 'optparse'
require 'pycall/import'
include PyCall::Import
require 'pandas'

# Use load_env to trace the path of .env:
Dotenv.load('.env')

client = OpenAI::Client.new(access_token: ENV['OPENAI_ACCESS_KEY'])

COMPLETIONS_MODEL = 'text-davinci-003'

MODEL_NAME = 'curie'

DOC_EMBEDDINGS_MODEL = "text-search-#{MODEL_NAME}-doc-001"

PyCall.pyfrom('transformers', import: 'GPT2TokenizerFast')
tokenizer = PyCall::GPT2TokenizerFast.from_pretrained('gpt2')

def count_tokens(text)
  # """count the number of tokens in a string"""
  tokenizer.encode(text).length
end

def extract_pages(page_text, index)
  # """
  # Extract the text from the page
  # """
  return [] if page_text.length == 0

  content = ' '.join(page_text.split)
  puts 'page text: ' + content
  # outputs = [("Page " + str(index), content, count_tokens(content)+4)]
  outputs = [{ title: 'Page ' + str(index), content:, tokens: count_tokens(content) + 4 }]
end

filename = 'placeholder.pdf'
OptionParser.new do |opt|
  opt.on('--pdf PDF') { |o| filename = o }
end.parse!
# pull filename from command line args

puts 'Reading PDF: ' + filename

reader = PDF::Reader.new(filename)
res = []
i = 1
reader.pages.each do |page|
  res += extract_pages(page.text, i)
  i += 1
end
df = Pandas.DataFrame.new(res, columns: %w[title content tokens])
df = df[df.tokens < 2046]
df = df.reset_index.drop('index', axis: 1) # reset index
df.head
df.to_csv(f('{filename}.pages.csv', index: false))

def get_embedding(text, model)
  result = client.embeddings(parameters: { model:, input: text })
  result['data'][0]['embedding']
end

def get_doc_embedding(text)
  get_embedding(text, DOC_EMBEDDINGS_MODEL)
end

def compute_doc_embeddings(_df)
  # Create an embedding for each row in the dataframe using the OpenAI Embeddings API.
  # Return a dictionary that maps between each embedding vector and the index of the row that it corresponds to.

  # return {
  #     idx: get_doc_embedding(r['content']) for idx, r in df.iterrows
  # }
  _df.map { |idx, r| [idx, get_doc_embedding(r['content'])] }.to_h
end

# CSV with exactly these named columns:
# "title", "0", "1", ... up to the length of the embedding vectors.

doc_embeddings = compute_doc_embeddings(df)

File.open(f('{filename}.embeddings.csv', 'w')) do |f|
  writer = CSV.writer(f)
  writer.writerow(['title'] + list(range(4096)))
  for i, embedding in list(doc_embeddings.items) do
    writer.writerow(['Page ' + str(i + 1)] + embedding)
  end
end
