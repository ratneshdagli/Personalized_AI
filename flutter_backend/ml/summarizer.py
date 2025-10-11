from sumy.parsers.plaintext import PlaintextParser
from sumy.nlp.tokenizers import Tokenizer
from sumy.summarizers.luhn import LuhnSummarizer

def summarize_text(text: str, sentence_count: int = 2) -> str:
    """
    Summarizes the given text to a specified number of sentences.
    """
    parser = PlaintextParser.from_string(text, Tokenizer("english"))
    summarizer = LuhnSummarizer()
    summary_sentences = summarizer(parser.document, sentence_count)
    
    summary = " ".join([str(sentence) for sentence in summary_sentences])
    return summary