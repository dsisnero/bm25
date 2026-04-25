module Bm25
  enum Language
    Arabic
    Danish
    Dutch
    English
    French
    German
    Greek
    Hungarian
    Italian
    Norwegian
    Portuguese
    Romanian
    Russian
    Spanish
    Swedish
    Tamil
    Turkish
  end

  enum LanguageMode
    Fixed
  end

  STOP_WORDS_ENGLISH = Set{
    "a", "about", "above", "after", "again", "against", "all", "am", "an", "and", "any",
    "are", "aren't", "as", "at", "be", "because", "been", "before", "being", "below",
    "between", "both", "but", "by", "can't", "cannot", "could", "couldn't", "did",
    "didn't", "do", "does", "doesn't", "doing", "don't", "down", "during", "each",
    "few", "for", "from", "further", "had", "hadn't", "has", "hasn't", "have", "haven't",
    "having", "he", "he'd", "he'll", "he's", "her", "here", "here's", "hers", "herself",
    "him", "himself", "his", "how", "how's", "i", "i'd", "i'll", "i'm", "i've", "if",
    "in", "into", "is", "isn't", "it", "it's", "its", "itself", "let's", "me", "more",
    "most", "mustn't", "my", "myself", "no", "nor", "not", "of", "off", "on", "once",
    "only", "or", "other", "ought", "our", "ours", "ourselves", "out", "over", "own",
    "same", "shan't", "she", "she'd", "she'll", "she's", "should", "shouldn't", "so",
    "some", "such", "than", "that", "that's", "the", "their", "theirs", "them",
    "themselves", "then", "there", "there's", "these", "they", "they'd", "they'll",
    "they're", "they've", "this", "those", "through", "to", "too", "under", "until",
    "up", "very", "was", "wasn't", "we", "we'd", "we'll", "we're", "we've", "were",
    "weren't", "what", "what's", "when", "when's", "where", "where's", "which",
    "while", "who", "who's", "whom", "why", "why's", "with", "won't", "would",
    "wouldn't", "you", "you'd", "you'll", "you're", "you've", "your", "yours",
    "yourself", "yourselves",
  }

  module Porter2
    VOWELS     = Set{'a', 'e', 'i', 'o', 'u', 'y'}
    LI_ENDINGS = Set{'c', 'd', 'e', 'g', 'h', 'k', 'm', 'n', 'r', 't'}
    DOUBLES    = Set{'l', 's', 'z'}

    def self.stem(word : String) : String
      return word if word.size <= 2
      w = word.downcase
      return w if w.size <= 2

      r1 = find_r1(w)
      r2 = find_r2(w, r1)

      w = step_0(w)
      w = step_1a(w)
      w = step_1b(w, r1)
      w = step_1c(w)
      w = step_2(w, r1)
      w = step_3(w, r1)
      w = step_4(w, r2)
      w = step_5(w, r1, r2)

      w
    end

    private def self.find_r1(w : String) : Int32
      return 1 if w =~ /^[aeiouy]/
      idx = w.index(/[aeiouy][^aeiouy]/)
      idx ? idx + 2 : w.size
    end

    private def self.find_r2(w : String, r1 : Int32) : Int32
      return w.size if r1 >= w.size
      idx = w.index(/[aeiouy][^aeiouy]/, r1)
      idx ? idx + 2 : w.size
    end

    private def self.ends_with?(w : String, suffix : String) : Bool
      w.ends_with?(suffix)
    end

    private def self.chop(w : String, suffix : String) : String
      w[0..(-suffix.size - 1)]
    end

    private def self.has_vowel?(w : String) : Bool
      w.each_char.any? { |c| VOWELS.includes?(c) }
    end

    private def self.has_vowel_in_stem?(w : String) : Bool
      w.rindex(/[aeiouy]/) != nil
    end

    private def self.ends_double?(w : String) : Bool
      return false if w.size < 2
      c = w[-1]
      w[-2] == c && DOUBLES.includes?(c)
    end

    private def self.li_ending?(w : String) : Bool
      return false if w.empty?
      LI_ENDINGS.includes?(w[-1])
    end

    private def self.short_syllable?(w : String, pos : Int32) : Bool
      return false if pos <= 0 || pos >= w.size - 1
      !VOWELS.includes?(w[pos - 1]) && VOWELS.includes?(w[pos]) && !VOWELS.includes?(w[pos + 1])
    end

    private def self.short_word?(w : String, r1 : Int32) : Bool
      return false if r1 < w.size
      return false if w.size < 2
      short_syllable?(w, w.size - 2)
    end

    private def self.step_0(w : String) : String
      return chop(w, "'s'") if ends_with?(w, "'s'") && w.size > 3
      return chop(w, "'s") if ends_with?(w, "'s") && w.size > 2
      while w.ends_with?("'") && w.size > 1
        w = chop(w, "'")
      end
      w
    end

    private def self.step_1a(w : String) : String
      return chop(w, "sses") + "ss" if ends_with?(w, "sses")
      if ends_with?(w, "ied") || ends_with?(w, "ies")
        stem = chop(w, w.ends_with?("ied") ? "ied" : "ies")
        return stem.size > 1 ? stem + "i" : stem + "ie"
      end
      if ends_with?(w, "us") || ends_with?(w, "ss")
        return w
      end
      if ends_with?(w, "s")
        stem = chop(w, "s")
        return stem if has_vowel_in_stem?(stem)
      end
      w
    end

    private def self.step_1b(w : String, r1 : Int32) : String
      if ends_with?(w, "eedly")
        stem = chop(w, "eedly")
        if stem.size >= r1
          return stem + "ee"
        end
      elsif ends_with?(w, "eed")
        stem = chop(w, "eed")
        if stem.size >= r1
          return stem + "ee"
        end
      elsif ends_with?(w, "ingly") || ends_with?(w, "edly") ||
            ends_with?(w, "ing") || ends_with?(w, "ed")
        suffix = %w[ingly edly ing ed].find { |s| ends_with?(w, s) } || ""
        stem = chop(w, suffix)
        if stem.empty? || !has_vowel_in_stem?(stem)
          return w
        end
        return step_1b_replace(stem)
      end
      w
    end

    private def self.step_1b_replace(stem : String) : String
      return chop(stem, "at") + "atte" if ends_with?(stem, "at")
      return chop(stem, "bl") + "bble" if ends_with?(stem, "bl")
      return chop(stem, "iz") + "izz" if ends_with?(stem, "iz")
      return chop(stem, "bb") if ends_with?(stem, "bb")
      return chop(stem, "dd") if ends_with?(stem, "dd")
      return chop(stem, "ff") if ends_with?(stem, "ff")
      return chop(stem, "gg") if ends_with?(stem, "gg")
      return chop(stem, "mm") if ends_with?(stem, "mm")
      return chop(stem, "nn") if ends_with?(stem, "nn")
      return chop(stem, "pp") if ends_with?(stem, "pp")
      return chop(stem, "rr") if ends_with?(stem, "rr")
      return chop(stem, "tt") if ends_with?(stem, "tt")
      return chop(stem, "zz") if ends_with?(stem, "zz")
      if ends_double?(stem)
        before_last = chop(stem, stem[-1].to_s)
        return before_last
      end
      return stem + "e" if short_word?(stem, find_r1(stem)) && has_vowel_in_stem?(stem)
      stem
    end

    private def self.step_1c(w : String) : String
      if ends_with?(w, "y") && w.size > 2 && !VOWELS.includes?(w[-2])
        chop(w, "y") + "i"
      else
        w
      end
    end

    private def self.step_2(w : String, r1 : Int32) : String
      return w if w.size < r1 + 3

      replacements = {
        "ization" => "ize", "fulness" => "ful", "iveness" => "ive",
        "ational" => "ate", "tional" => "tion", "biliti" => "ble",
        "lessli" => "less", "ousli" => "ous", "entli" => "ent",
        "ation" => "ate", "alism" => "al", "aliti" => "al",
        "iviti" => "ive", "fulli" => "ful", "enci" => "ence",
        "anci" => "ance", "izer" => "ize", "abli" => "able",
        "alli" => "al", "ator" => "ate", "logi" => "log",
      }
      replacements.each do |suffix, replacement|
        if ends_with?(w, suffix)
          stem = chop(w, suffix)
          return stem + replacement if stem.size >= r1
        end
      end
      w
    end

    private def self.step_3(w : String, r1 : Int32) : String
      replacements = {
        "icate" => "ic", "ative" => "", "alize" => "al",
        "iciti" => "ic", "ical" => "ic", "ness" => "",
        "ful" => "",
      }
      replacements.each do |suffix, replacement|
        if ends_with?(w, suffix)
          stem = chop(w, suffix)
          return stem + replacement if stem.size >= r1
        end
      end
      w
    end

    private def self.step_4(w : String, r2 : Int32) : String
      return w if w.size < r2 + 2

      replacements = {
        "ance" => "", "ence" => "", "able" => "", "ible" => "",
        "ment" => "", "ant" => "", "ent" => "",
        "ism" => "", "ate" => "", "iti" => "", "ous" => "",
        "ive" => "", "ize" => "",
        "ion" => "",
      }
      replacements.each do |suffix, replacement|
        if ends_with?(w, suffix)
          if suffix == "ion"
            stem = chop(w, "ion")
            return stem if stem.size >= r2 && stem[-1].in?('s', 't')
          else
            stem = chop(w, suffix)
            return stem + replacement if stem.size >= r2
          end
        end
      end
      w
    end

    private def self.step_5(w : String, r1 : Int32, r2 : Int32) : String
      if ends_with?(w, "e")
        stem = chop(w, "e")
        if r2 < w.size || (r1 < w.size && !short_word?(stem, find_r1(stem)))
          return stem
        end
      end
      if ends_with?(w, "l") && w.size > r2 && ends_double?(w)
        return chop(w, "l")
      end
      w
    end
  end

  ASCII_FOLD = {
    'À' => 'A', 'Á' => 'A', 'Â' => 'A', 'Ã' => 'A', 'Ä' => 'A', 'Å' => 'A',
    'à' => 'a', 'á' => 'a', 'â' => 'a', 'ã' => 'a', 'ä' => 'a', 'å' => 'a',
    'Ç' => 'C', 'ç' => 'c',
    'È' => 'E', 'É' => 'E', 'Ê' => 'E', 'Ë' => 'E',
    'è' => 'e', 'é' => 'e', 'ê' => 'e', 'ë' => 'e',
    'Ì' => 'I', 'Í' => 'I', 'Î' => 'I', 'Ï' => 'I',
    'ì' => 'i', 'í' => 'i', 'î' => 'i', 'ï' => 'i',
    'Ñ' => 'N', 'ñ' => 'n',
    'Ò' => 'O', 'Ó' => 'O', 'Ô' => 'O', 'Õ' => 'O', 'Ö' => 'O',
    'ò' => 'o', 'ó' => 'o', 'ô' => 'o', 'õ' => 'o', 'ö' => 'o', 'ø' => 'o',
    'Ø' => 'O',
    'ß' => "ss",
    'Ù' => 'U', 'Ú' => 'U', 'Û' => 'U', 'Ü' => 'U',
    'ù' => 'u', 'ú' => 'u', 'û' => 'u', 'ü' => 'u',
    'Ý' => 'Y', 'ý' => 'y', 'ÿ' => 'y',
    'æ' => "ae", 'Æ' => "ae",
    'œ' => "oe", 'Œ' => "oe",
    'þ' => "th", 'Þ' => "th",
    'đ' => "d", 'Đ' => "d",
    'ð' => "d", 'Ð' => "d",
    'ł' => "l", 'Ł' => "l",
    'ı' => "i",
    'ğ' => "g", 'Ğ' => "g",
    'ş' => "s", 'Ş' => "S",
    'č' => "c", 'Č' => "C",
    'š' => "s", 'Š' => "S",
    'ž' => "z", 'Ž' => "Z",
    'ő' => "o", 'Ő' => "O",
    'ű' => "u", 'Ű' => "U",
  }

  EMOJI_TEXTS = {
    "\u{1F355}" => "pizza",
    "\u{1F680}" => "rocket",
    "\u{1F34B}" => "lemon",
    "\u{1F525}" => "fire",
  }

  def self.deunicode(text : String) : String
    String.build(text.size) do |io|
      text.each_char do |ch|
        if replacement = ASCII_FOLD[ch]?
          io << replacement
        elsif ch.ord > 127
          if emoji_text = EMOJI_TEXTS[ch]?
            io << emoji_text
          else
            io << "[?]"
          end
        else
          io << ch
        end
      end
    end
  end

  def self.split_unicode_words(text : String) : Array(String)
    tokens = [] of String
    current = String::Builder.new
    i = 0
    chars = text.chars
    while i < chars.size
      ch = chars[i]
      if ch.alphanumeric? || ch == '\'' || ch == '_'
        current << ch
      elsif ch == '-' && current.bytesize > 0
        current << ch
      elsif ch == '.' && current.bytesize > 0 && i + 1 < chars.size && chars[i + 1].number?
        current << ch
      else
        if current.bytesize > 0
          token = current.to_s
          tokens << token unless token.empty?
          current = String::Builder.new
        end
      end
      i += 1
    end
    if current.bytesize > 0
      token = current.to_s
      tokens << token unless token.empty?
    end
    tokens.reject! { |t| t.each_char.all? { |c| c == '-' || c == '\'' || c == '_' } }
    tokens
  end

  class DefaultTokenizer < Tokenizer
    def initialize(@language : Language = Language::English, @normalization : Bool = true, @stemming : Bool = true, @stopwords : Bool = true)
    end

    def self.new(language_mode : LanguageMode) : DefaultTokenizer
      new
    end

    def self.builder : DefaultTokenizerBuilder
      DefaultTokenizerBuilder.new
    end

    def tokenize(input_text : String) : Array(String)
      return [] of String if input_text.empty?

      text = input_text
      text = Bm25.deunicode(text) if @normalization
      text = text.downcase

      tokens = Bm25.split_unicode_words(text)

      tokens.reject! { |t| STOP_WORDS_ENGLISH.includes?(t) } if @stopwords

      tokens.map! { |t| Porter2.stem(t) } if @stemming

      tokens
    end
  end

  class DefaultTokenizerBuilder
    def initialize(@language : Language = Language::English, @normalization : Bool = true, @stemming : Bool = true, @stopwords : Bool = true)
    end

    def language(mode : Language) : self
      @language = mode
      self
    end

    def normalization(v : Bool) : self
      @normalization = v
      self
    end

    def stemming(v : Bool) : self
      @stemming = v
      self
    end

    def stopwords(v : Bool) : self
      @stopwords = v
      self
    end

    def build : DefaultTokenizer
      DefaultTokenizer.new(@language, @normalization, @stemming, @stopwords)
    end
  end
end
