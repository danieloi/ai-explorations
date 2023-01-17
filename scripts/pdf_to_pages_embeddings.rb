require 'dotenv'
require 'openai'
require 'csv'
require 'pdf-reader'
require 'optparse'
require "pycall/import"
include PyCall::Import
require 'pandas'

# Use load_env to trace the path of .env:
Dotenv.load('.env')

Openai.api_key = ENV["OPENAI_API_KEY"]

COMPLETIONS_MODEL = "text-davinci-003"

MODEL_NAME = "curie"

DOC_EMBEDDINGS_MODEL = f"text-search-{MODEL_NAME}-doc-001"

PyCall.pyfrom("transformers", import: "GPT2TokenizerFast")
tokenizer = PyCall::GPT2TokenizerFast.from_pretrained("gpt2")

def count_tokens(text: str) -> int
    """count the number of tokens in a string"""
    return tokenizer.encode(text).length
end

def extract_pages(page_text: str, index: int) -> str
    """
    Extract the text from the page
    """
    if page_text.length == 0
        return []
    end
    content = " ".join(page_text.split())
    puts "page text: " + content
    outputs = [("Page " + str(index), content, count_tokens(content)+4)]
    return outputs
end

parser = OptionParser.new
parser.on('-p', '--pdf PDF', 'Name of PDF') { |v| @pdf = v }
args = parser.parse
filename = @pdf
reader = PDF::Reader.new(filename)
res = []
i = 1
reader.pages.each do |page|
    res += extract_pages(page.extract_text, i)
    i += 1
end
df = Pandas.DataFrame.new(res, columns: ["title", "content", "tokens"])
df = df[df.tokens < 2046]
df = df.reset_index().drop('index', axis: 1)  # reset index
df.head()
df.to_csv(f'{filename}.pages.csv', index: false)

def get_embedding(text: str, model: str) -> list[float]
    result = Openai::Embedding.create(
        model: model,
        input: text
    )
    return result["data"][0]["embedding"]
end

def get_doc_embedding(text: str) -> list[float]
    return get_embedding(text, DOC_EMBEDDINGS_MODEL)
end

def compute_doc_embeddings(df: Pandas::DataFrame) -> dict[tuple[str], list[float]]
    """
    Create an embedding for each row in the dataframe using the OpenAI Embeddings API.

    Return a dictionary that maps between each embedding vector and the index of the row that it corresponds to.
    """
    return {
        idx: get_doc_embedding(r.content) for idx, r in df.iterrows
    }
end

CSV with exactly these named columns:
"title", "0", "1", ... up to the length of the embedding vectors.

doc_embeddings = compute_doc_embeddings(df)

File.open(f'{filename}.embeddings.csv', 'w') do |f|
    writer = CSV.writer(f)
    writer.writerow(["title"] + list(range(4096)))
    for i, embedding in list(doc_embeddings.items) do
        writer.writerow(["Page " + str(i + 1)] + embedding)
    end
end
