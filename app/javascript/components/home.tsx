import React, { useState } from "react";
import BookImage from "./book.png";

const DEFAULT_QUESTION = "What is The Minimalist Entrepreneur about?";
export default function home() {
  const [question, setQuestion] = useState(DEFAULT_QUESTION);
  const [answer, setAnswer] = useState("");
  const [isFetching, setIsFetching] = useState(false);
  const textAreaRef = React.useRef(null!);

  const handleTextAreaChange = (event) => {
    setQuestion(event.target.value);
    //   clear answer if user starts typing a new question
    if (answer) {
      setAnswer("");
    }
  };

  const handleSubmit = (event) => {
    event.preventDefault();
    if (question == "") {
      alert("Please ask a question!");
      return;
    }
    setIsFetching(true);
    fetch("/ask", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ question }),
    })
      .then((response) => response.json())
      .then((data) => {
        setAnswer(data.answer);
        setIsFetching(false);
      })
      .catch((error) => {
        console.error("Error:", error);
        setIsFetching(false);
      });
  };

  const handleAskAnother = (event) => {
    event.preventDefault();
    setAnswer("");
    setQuestion(DEFAULT_QUESTION);
    textAreaRef.current.select();
  };

  return (
    <>
      <div className="header">
        <div className="logo">
          <a href="https://www.amazon.com/Minimalist-Entrepreneur-Great-Founders-More/dp/0593192397">
            <img src={BookImage} loading="lazy" />
          </a>
          <h1>Ask My Book</h1>
        </div>
      </div>
      <div className="main">
        <p className="credits">
          This is an experiment in using AI to make my book's content more
          accessible. Ask a question and AI'll answer it in real-time:
        </p>

        <form method="post">
          <textarea
            name="question"
            id="question"
            onChange={handleTextAreaChange}
            value={question}
            ref={textAreaRef}
          ></textarea>
          <div
            className="buttons"
            style={{
              display: answer ? "none" : "flex",
            }}
            onClick={handleSubmit}
          >
            <button type="submit" id="ask-button" disabled={isFetching}>
              {isFetching ? "Asking" : "Ask question"}
            </button>
          </div>
        </form>
        <p id="answer-container" className={answer ? "showing" : "hidden"}>
          <strong>Answer:</strong> <span id="answer">{answer}</span>{" "}
          <button
            id="ask-another-button"
            style={{ display: "block" }}
            onClick={handleAskAnother}
          >
            Ask another question
          </button>
        </p>
      </div>
      <footer>
        <p className="credits">
          Project by <a href="https://twitter.com/shl">Sahil Lavingia</a> •{" "}
          <a href="https://github.com/slavingia/askmybook">Fork on GitHub</a>
        </p>
      </footer>
    </>
  );
}
