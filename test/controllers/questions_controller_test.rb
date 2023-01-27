require 'test_helper'

class QuestionsControllerTest < ActionDispatch::IntegrationTest
  test 'should compute dot product of two vectors' do
    assert_equal 32, QuestionsController.new.vector_similarity([1, 2, 3], [4, 5, 6])
  end

  test 'should load embeddings' do
    embeddings = QuestionsController.new.load_embeddings('test/fixtures/files/book.pdf.embeddings.csv')
    assert_equal 4096, embeddings['Page 1'].length
  end

  test 'should answer a question' do
    post '/ask', params: { question: "what's the name of the author?" }
    answer = @response.parsed_body['answer']
    # assert if "Sahil Lavingia" is contained in the answer
    assert answer.include?('Sahil Lavingia')
  end
end
