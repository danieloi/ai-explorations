class QuestionsController < ApplicationController
  before_action :initialize_openai_client
  skip_before_action :verify_authenticity_token
  SEPARATOR_LEN = 3
  SEPARATOR = "\n* ".freeze
  MAX_SECTION_LEN = 500

  COMPLETIONS_MODEL = 'text-davinci-003'.freeze
  COMPLETIONS_API_PARAMS = {
    # We use temperature of 0.0 because it gives the most predictable, factual answer.
    "temperature": 0.0,
    "max_tokens": 150,
    "model": COMPLETIONS_MODEL
  }

  MODEL_NAME = 'curie'.freeze

  QUERY_EMBEDDINGS_MODEL = "text-search-#{MODEL_NAME}-query-001".freeze

  def index; end

  def ask
    # get the question from the post request body
    @question = params[:question]
    # if it doesn't end with a question mark, add one
    @question += '?' unless @question.end_with?('?')

    @previous_question = Question.find_by question: @question

    if @previous_question
      # if we've seen this question before, just return the answer
      @previous_question.ask_count += 1
      @previous_question.save
      render json: @previous_question
      return
    end

    df = Daru::DataFrame.from_csv('book.pdf.pages.csv')
    df.index = df['title'].to_a
    document_embeddings = load_embeddings('book.pdf.embeddings.csv')
    answer, context = answer_query_with_context(@question, df, document_embeddings)

    @question = Question.new({
                               question: @question,
                               answer:,
                               context:,
                               ask_count: 1
                             })

    if @question.save
      render json: { question: @question.question, answer: @question.answer }
    else
      render json: @question.errors, status: :unprocessable_entity
    end
  end

  def load_embeddings(file_name)
    # Read the document embeddings and their keys from a CSV.

    # file_name is the path to a CSV with exactly these named columns:
    #     "title", "0", "1", ... up to the length of the embedding vectors.
    df = Daru::DataFrame.from_csv(file_name)
    max_dim = df.ncols - 1
    # Create a dictionary that maps between each embedding vector and the index of the row that it corresponds to.
    embeddings = {}
    df.each_row do |row|
      embeddings[row['title']] = row[1...max_dim].to_a
    end
    embeddings
  end

  def answer_query_with_context(query, df, document_embeddings)
    prompt, context = construct_prompt(query, document_embeddings, df)

    print("prompt: \n", prompt, "\n")

    response = @openai_client.completions(
      parameters: {
        prompt:,
        **COMPLETIONS_API_PARAMS
      }
    )

    [response['choices'][0]['text'].strip, context]
  end

  def construct_prompt(question, context_embeddings, df)
    # Fetch relevant embeddings

    most_relevant_document_sections = order_document_sections_by_query_similarity(question, context_embeddings)
    chosen_sections = []
    chosen_sections_len = 0
    chosen_sections_indexes = []

    most_relevant_document_sections.each do |_, section_index|
      document_section = df.row[section_index].to_h

      chosen_sections_len += document_section['tokens'] + SEPARATOR_LEN
      if chosen_sections_len > MAX_SECTION_LEN
        space_left = MAX_SECTION_LEN - chosen_sections_len - SEPARATOR.length
        chosen_sections << SEPARATOR + document_section['content'][0...space_left]
        chosen_sections_indexes << section_index
        break
      end

      chosen_sections << SEPARATOR + document_section['content']
      chosen_sections_indexes << section_index
    end

    header = "Sahil Lavingia is the founder and CEO of Gumroad, and the author of the book The Minimalist Entrepreneur
    (also known as TME). These are questions and answers by him. Please keep your answers to three sentences maximum,
    and speak in complete sentences. Stop speaking once your point is made.\n\nContext that may be useful, pulled
    from The Minimalist Entrepreneur:\n"

    question1 = "\n\n\nQ: How to choose what business to start?\n\nA: First off don't be in a rush. Look around you,
    see what problems you or other people are facing, and solve one of these problems if you see some overlap with
    your passions or skills. Or, even if you don't see an overlap, imagine how you would solve that problem anyway.
    Start super, super small."
    question2 = "\n\n\nQ: Q: Should we start the business on the side first or should we put full effort right from the
    start?\n\nA:   Always on the side. Things start small and get bigger from there, and I don't know if I would ever
    “fully” commit to something unless I had some semblance of customer traction. Like with this product I'm
    working on now!"
    question3 = "\n\n\nQ: Should we sell first than build or the other way around?\n\nA: I would recommend
    building first. Building will teach you a lot, and too many people use “sales” as an excuse to never learn
    essential skills like building. You can't sell a house you can't build!"
    question4 = "\n\n\nQ: Andrew Chen has a book on this so maybe touché, but how should founders think about
    the cold start problem? Businesses are hard to start, and even harder to sustain but the latter is somewhat defined
    and structured, whereas the former is the vast unknown. Not sure if it's worthy, but this is something
    I have personally struggled with\n\nA: Hey, this is about my book, not his! I would solve the problem from a single
    player perspective first. For example, Gumroad is useful to a creator looking to sell something even if no one
    is currently using the platform. Usage helps, but it's not necessary."
    question5 = "\n\n\nQ: What is one business that you think is ripe for a minimalist Entrepreneur innovation that
    isn't currently being pursued by your community?\n\nA: I would move to a place outside of a big city and watch how
    broken, slow, and non-automated most things are. And of course the big categories like housing, transportation, toys,
    healthcare, supply chain, food, and more, are constantly being upturned. Go to an industry conference and it's all
    they talk about! Any industry…"
    question6 = "\n\n\nQ: How can you tell if your pricing is right? If you are leaving money on the table\n\nA: I would
    work backwards from the kind of success you want, how many customers you think you can reasonably get to within a
    few years, and then reverse engineer how much it should be priced to make that work."
    question7 = "\n\n\nQ: Why is the name of your book 'the minimalist entrepreneur' \n\nA: I think more people should
    start businesses, and was hoping that making it feel more “minimal” would make it feel more achievable and lead more
    people to starting-the hardest step."
    question8 = "\n\n\nQ: How long it takes to write TME\n\nA: About 500 hours over the course of a year or two, including
    book proposal and outline."
    question9 = "\n\n\nQ: What is the best way to distribute surveys to test my product idea\n\nA: I use Google Forms
    and my email list / Twitter account. Works great and is 100% free."
    question10 = "\n\n\nQ: How do you know, when to quit\n\nA: When I'm bored, no longer learning, not earning enough,
    getting physically unhealthy, etc… loads of reasons. I think the default should be to “quit” and work on
    something new. Few things are worth holding your attention for a long period of time."

    [
      (header + chosen_sections.join('') + question1 + question2 + question3 + question4 + question5 + question6 + question7 + question8 + question9 + question10 + "\n\n\nQ: " + question + "\n\nA: "), chosen_sections.join('')
    ]
  end

  def vector_similarity(x, y)
    # We could use cosine similarity or dot product to calculate the similarity between vectors.
    # In practice, we have found it makes little difference.
    a = Vector[*x]
    b = Vector[*y]
    a.inner_product(b)
  end

  def order_document_sections_by_query_similarity(query, contexts)
    # Find the query embedding for the supplied query, and compare it against all of the pre-calculated document
    # embeddings to find the most relevant sections.

    # Return the list of document sections, sorted by relevance in descending order.

    query_embedding = get_query_embedding(query)

    result = []
    contexts.to_a.each do |doc_index, doc_embedding|
      result << [vector_similarity(query_embedding, doc_embedding), doc_index]
    end

    result.sort.reverse
  end

  def get_query_embedding(text)
    get_embedding(text, QUERY_EMBEDDINGS_MODEL)
  end

  def get_embedding(text, model)
    result = @openai_client.embeddings(
      parameters: {
        model:, input: text
      }
    )
    result['data'][0]['embedding']
  end

  private

  def initialize_openai_client
    @openai_client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
  end
end
