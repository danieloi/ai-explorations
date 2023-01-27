# README

## Deployed site

https://afternoon-river-75904.herokuapp.com/
## Setup  

Clone the repo and make sure your `.env` file is present and contains the `OPENAI_API_KEY` variable.

Install dependencies with

```bundle install```

for the frontend be sure to also run

```yarn install```

run the test suite with

```bin/rails test```

make sure you've installed postgres


start the development server with

```bin/dev```

you can run the pdf_to_pages_embeddings script from the root with

```bundle exec ruby scripts/pdf_to_pages_embeddings.rb```

Note:

You want the `book.pdf` file in the root of the project when you're running the script.

You also want to be sure you've installed the necessary dependencies and have the environment 
variable `OPENAI_API_KEY` set.

## Architecture decisions  

### Frontend  

Used react as instructed.
Tried to keep things as simple as possible so I didn't pull out the
big guns like redux or a query library.

Used esbuild so builds are super quick

### Backend & Script  

Used ruby and rails as instructed.

I almost did a line by line translation from python to ruby for the script and `/ask` endpoint.

There's a `pycall` instance for the script so we could tokenize the text in ruby but every other
thing used a pure ruby implementation.

The pain of this take-home made me sure python is the better language for tasks like these since ruby gems in the data engineering space aren't nearly as supported or mature.

I remember Bill Gates mentioning what he'd work on if he were younger and starting afresh.

He mentioned having computers answer intelligently from a body of text and it's so exciting that we're pretty much there!