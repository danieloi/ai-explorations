require 'test_helper'

class QuestionTest < ActiveSupport::TestCase
  test 'should not save without question field' do
    question = Question.new
    assert_not question.save
  end
end
