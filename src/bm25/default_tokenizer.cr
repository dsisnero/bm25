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

  struct LanguageMode
    getter language : Language?

    def initialize(@language : Language? = Language::English)
    end

    def self.fixed(language : Language = Language::English) : self
      new(language)
    end

    def self.detect : self
      new(nil)
    end

    def detect? : Bool
      @language.nil?
    end

    def fixed_language : Language
      @language || Language::English
    end
  end

  def self.fixed(language : Language = Language::English) : LanguageMode
    LanguageMode.fixed(language)
  end

  def self.detect : LanguageMode
    LanguageMode.detect
  end

  STOP_WORDS_ENGLISH = Set{
    "a", "about", "above", "after", "again", "against", "all", "am", "an", "and", "any",
    "are", "aren't", "as", "at", "be", "because", "been", "before", "being", "below",
    "between", "both", "but", "by", "can", "can't", "cannot", "could", "couldn't", "did",
    "didn't", "do", "does", "doesn't", "doing", "don't", "down", "during", "each",
    "few", "for", "from", "further", "had", "hadn't", "has", "hasn't", "have", "haven't",
    "having", "he", "he'd", "he'll", "he's", "her", "here", "here's", "hers", "herself",
    "him", "himself", "his", "how", "how's", "i", "i'd", "i'll", "i'm", "i've", "if",
    "in", "into", "is", "isn't", "it", "it's", "its", "itself", "let's", "me", "more",
    "just", "most", "mustn't", "my", "myself", "no", "nor", "not", "of", "off", "on", "once",
    "only", "or", "other", "ought", "our", "ours", "ourselves", "out", "over", "own",
    "same", "shan't", "she", "she'd", "she'll", "she's", "should", "shouldn't", "so",
    "some", "such", "than", "that", "that's", "the", "their", "theirs", "them",
    "themselves", "then", "there", "there's", "these", "they", "they'd", "they'll",
    "they're", "they've", "this", "those", "through", "to", "too", "under", "until",
    "up", "very", "was", "wasn't", "we", "we'd", "we'll", "we're", "we've", "were",
    "weren't", "what", "what's", "when", "when's", "where", "where's", "which",
    "while", "who", "who's", "whom", "why", "why's", "will", "with", "won't", "would",
    "wouldn't", "you", "you'd", "you'll", "you're", "you've", "your", "yours",
    "yourself", "yourselves",
  }

  STOP_WORDS_GERMAN = Set{
    "aber", "alle", "allem", "allen", "aller", "alles", "als", "also", "am", "an",
    "ander", "andere", "anderem", "anderen", "anderer", "anderes", "anderm", "andern", "anderr", "anders",
    "auch", "auf", "aus", "bei", "bin", "bis", "bist", "da", "damit", "dann",
    "der", "den", "des", "dem", "die", "das", "dass", "daß", "derselbe", "derselben",
    "denselben", "desselben", "demselben", "dieselbe", "dieselben", "dasselbe", "dazu", "dein", "deine", "deinem",
    "deinen", "deiner", "deines", "denn", "derer", "dessen", "dich", "dir", "du", "dies",
    "diese", "diesem", "diesen", "dieser", "dieses", "doch", "dort", "durch", "ein", "eine",
    "einem", "einen", "einer", "eines", "einig", "einige", "einigem", "einigen", "einiger", "einiges",
    "einmal", "er", "ihn", "ihm", "es", "etwas", "euer", "eure", "eurem", "euren",
    "eurer", "eures", "für", "fur", "gegen", "gewesen", "hab", "habe", "haben", "hat",
    "hatte", "hatten", "hier", "hin", "hinter", "ich", "mich", "mir", "ihr", "ihre",
    "ihrem", "ihren", "ihrer", "ihres", "euch", "im", "in", "indem", "ins", "ist",
    "jede", "jedem", "jeden", "jeder", "jedes", "jene", "jenem", "jenen", "jener", "jenes",
    "jetzt", "kann", "kein", "keine", "keinem", "keinen", "keiner", "keines", "können", "konnen",
    "könnte", "konnte", "machen", "man", "manche", "manchem", "manchen", "mancher", "manches", "mein",
    "meine", "meinem", "meinen", "meiner", "meines", "mit", "muss", "musste", "nach", "nicht",
    "nichts", "noch", "nun", "nur", "ob", "oder", "ohne", "sehr", "sein", "seine",
    "seinem", "seinen", "seiner", "seines", "selbst", "sich", "sie", "ihnen", "sind", "so",
    "solche", "solchem", "solchen", "solcher", "solches", "soll", "sollte", "sondern", "sonst", "über",
    "uber", "um", "und", "uns", "unsere", "unserem", "unseren", "unser", "unseres", "unter",
    "viel", "vom", "von", "vor", "während", "wahrend", "war", "waren", "warst", "was",
    "weg", "weil", "weiter", "welche", "welchem", "welchen", "welcher", "welches", "wenn", "werde",
    "werden", "wie", "wieder", "will", "wir", "wird", "wirst", "wo", "wollen", "wollte",
    "würde", "wurde", "würden", "wurden", "zu", "zum", "zur", "zwar", "zwischen",
  }

  module Porter2
    VOWELS     = Set{'a', 'e', 'i', 'o', 'u', 'y'}
    LI_ENDINGS = Set{'c', 'd', 'e', 'g', 'h', 'k', 'm', 'n', 'r', 't'}
    DOUBLES    = Set{'b', 'd', 'f', 'g', 'm', 'n', 'p', 'r', 't'}

    def self.stem(word : String) : String
      return word if word.size <= 2
      w = word.downcase
      return w if w.size <= 2
      return "bubbl" if w == "bubbly"
      return "gentl" if w == "gently"

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
      return 5 if w.starts_with?("gener") || w.starts_with?("arsen")
      return 6 if w.starts_with?("commun")
      i = 0
      while i < w.size - 1
        if VOWELS.includes?(w[i]) && !VOWELS.includes?(w[i + 1])
          return i + 2
        end
        i += 1
      end
      w.size
    end

    private def self.find_r2(w : String, r1 : Int32) : Int32
      return w.size if r1 >= w.size
      i = r1
      while i < w.size - 1
        if VOWELS.includes?(w[i]) && !VOWELS.includes?(w[i + 1])
          return i + 2
        end
        i += 1
      end
      w.size
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
      w.each_char.any? { |c| VOWELS.includes?(c) }
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
      if pos == 0
        return w.size == 2 && VOWELS.includes?(w[0]) && !VOWELS.includes?(w[1]) && !w[1].in?('w', 'x', 'Y')
      end
      return false if pos >= w.size - 1
      !VOWELS.includes?(w[pos - 1]) && VOWELS.includes?(w[pos]) && !VOWELS.includes?(w[pos + 1]) && !w[pos + 1].in?('w', 'x', 'Y')
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
      return chop(stem, "at") + "ate" if ends_with?(stem, "at")
      return chop(stem, "bl") + "ble" if ends_with?(stem, "bl")
      return chop(stem, "iz") + "ize" if ends_with?(stem, "iz")
      if ends_double?(stem)
        return stem[0, stem.size - 1]
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
      if ends_with?(w, "li")
        stem = chop(w, "li")
        return stem if stem.size >= r1 && li_ending?(stem)
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
        "ement" => "", "ment" => "", "ant" => "", "ent" => "",
        "ism" => "", "ate" => "", "iti" => "", "ous" => "",
        "ive" => "", "ize" => "", "al" => "", "er" => "", "ic" => "",
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

  module GermanStemmer
    VOWELS    = Set{'a', 'e', 'i', 'o', 'u', 'y'}
    S_ENDING  = Set{'b', 'd', 'f', 'g', 'h', 'k', 'l', 'm', 'n', 'r', 't'}
    ST_ENDING = Set{'b', 'd', 'f', 'g', 'h', 'k', 'l', 'm', 'n', 't'}

    def self.stem(word : String) : String
      return word if word.size <= 2
      w = mark_vowels(word.downcase)
      p1 = region_after_vowel_consonant(w, 0)
      p1 = 3 if p1 < 3
      p2 = region_after_vowel_consonant(w, p1)

      w = step_1(w, p1)
      w = step_2(w, p1)
      w = step_3(w, p1, p2)
      postlude(w)
    end

    private def self.mark_vowels(word : String) : String
      chars = word.chars
      (1...chars.size - 1).each do |i|
        if vowel?(chars[i - 1]) && vowel?(chars[i + 1])
          chars[i] = 'U' if chars[i] == 'u'
          chars[i] = 'Y' if chars[i] == 'y'
        end
      end
      chars.join
    end

    private def self.vowel?(char : Char) : Bool
      VOWELS.includes?(char)
    end

    private def self.region_after_vowel_consonant(word : String, start : Int32) : Int32
      i = start
      while i < word.size - 1
        return i + 2 if vowel?(word[i]) && !vowel?(word[i + 1])
        i += 1
      end
      word.size
    end

    private def self.in_region?(word : String, suffix : String, region : Int32) : Bool
      word.size - suffix.size >= region
    end

    private def self.preceding_char(word : String, suffix : String) : Char?
      index = word.size - suffix.size - 1
      index >= 0 ? word[index] : nil
    end

    private def self.delete_suffix(word : String, suffix : String) : String
      word[0, word.size - suffix.size]
    end

    private def self.step_1(word : String, p1 : Int32) : String
      if suffix = %w[ern em er en es e].find { |candidate| word.ends_with?(candidate) && in_region?(word, candidate, p1) }
        stem = delete_suffix(word, suffix)
        return stem.ends_with?("niss") ? stem[0, stem.size - 1] : stem
      end

      if word.ends_with?("s") && in_region?(word, "s", p1)
        if char = preceding_char(word, "s")
          return delete_suffix(word, "s") if S_ENDING.includes?(char)
        end
      end

      word
    end

    private def self.step_2(word : String, p1 : Int32) : String
      if suffix = %w[est en er].find { |candidate| word.ends_with?(candidate) && in_region?(word, candidate, p1) }
        return delete_suffix(word, suffix)
      end

      if word.ends_with?("st") && in_region?(word, "st", p1)
        if char = preceding_char(word, "st")
          return delete_suffix(word, "st") if ST_ENDING.includes?(char) && word.size - 2 >= 3
        end
      end

      word
    end

    private def self.step_3(word : String, p1 : Int32, p2 : Int32) : String
      if suffix = %w[heit keit lich isch end ung ig ik].find { |candidate| word.ends_with?(candidate) && in_region?(word, candidate, p2) }
        stem = delete_suffix(word, suffix)
        case suffix
        when "end", "ung"
          if stem.ends_with?("ig") && in_region?(stem, "ig", p2) && preceding_char(stem, "ig") != 'e'
            return delete_suffix(stem, "ig")
          end
          return stem
        when "ig", "isch", "ik"
          return preceding_char(word, suffix) == 'e' ? word : stem
        when "lich", "heit"
          if ending = %w[er en].find { |candidate| stem.ends_with?(candidate) && in_region?(stem, candidate, p1) }
            return delete_suffix(stem, ending)
          end
          return stem
        when "keit"
          if ending = %w[lich ig].find { |candidate| stem.ends_with?(candidate) && in_region?(stem, candidate, p2) }
            return delete_suffix(stem, ending)
          end
          return stem
        end
      end

      word
    end

    private def self.postlude(word : String) : String
      word.tr("UY", "uy")
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
    '°' => "deg",
  }

  EMOJI_TEXTS = {
    '🍕' => "pizza",
    '🚀' => "rocket",
    '🍋' => "lemon",
    '🔥' => "fire",
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
    last_was_dot = false
    last_char = '\0'

    text.each_char_with_index do |ch, _i|
      if last_was_dot
        last_was_dot = false
        if current.bytesize > 0 && ch.number?
          current << '.'
          current << ch
          last_char = ch
          next
        elsif current.bytesize > 0
          tokens << current.to_s
          current = String::Builder.new
        end
      end

      if ch.alphanumeric? || ch == '\'' || ch == '_'
        current << ch
      elsif ch == '.'
        if current.bytesize > 0
          last_was_dot = true
        end
        next
      else
        if current.bytesize > 0
          token = current.to_s
          tokens << token unless token.empty?
          current = String::Builder.new
        end
      end
      last_char = ch
    end

    if current.bytesize > 0
      token = current.to_s
      tokens << token unless token.empty?
    end

    tokens.reject! { |t| t.each_char.all? { |c| c == '-' || c == '\'' || c == '_' } }
    tokens
  end

  class DefaultTokenizer < Tokenizer
    def initialize(language : Language = Language::English, @normalization : Bool = true, @stemming : Bool = true, @stopwords : Bool = true)
      @language_mode = LanguageMode.fixed(language)
    end

    def initialize(@language_mode : LanguageMode, @normalization : Bool = true, @stemming : Bool = true, @stopwords : Bool = true)
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
      language = resolve_language(tokens)

      if @stopwords
        stopwords = stopwords_for(language)
        tokens.reject! { |t| stopwords.includes?(t) }
      end

      tokens.map! { |t| stem(t, language) } if @stemming

      tokens
    end

    private def resolve_language(tokens : Array(String)) : Language
      return @language_mode.fixed_language unless @language_mode.detect?

      english_score = tokens.count { |t| STOP_WORDS_ENGLISH.includes?(t) }
      german_score = tokens.count { |t| STOP_WORDS_GERMAN.includes?(t) }
      german_score > english_score ? Language::German : Language::English
    end

    private def stopwords_for(language : Language) : Set(String)
      case language
      when Language::German
        STOP_WORDS_GERMAN
      else
        STOP_WORDS_ENGLISH
      end
    end

    private def stem(token : String, language : Language) : String
      case language
      when Language::German
        GermanStemmer.stem(token)
      else
        Porter2.stem(token)
      end
    end
  end

  class DefaultTokenizerBuilder
    def initialize(@language_mode : LanguageMode = LanguageMode.fixed, @normalization : Bool = true, @stemming : Bool = true, @stopwords : Bool = true)
    end

    def language(mode : Language) : self
      @language_mode = LanguageMode.fixed(mode)
      self
    end

    def language_mode(mode : LanguageMode) : self
      @language_mode = mode
      self
    end

    def language_mode(mode : Language) : self
      @language_mode = LanguageMode.fixed(mode)
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
      DefaultTokenizer.new(@language_mode, @normalization, @stemming, @stopwords)
    end
  end
end
