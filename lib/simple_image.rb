$KCODE = 'u'
require 'jcode'
require 'rubygems'
require 'RMagick'
require 'base64'

#
#= RMagickを利用した画像処理を簡単にできるクラスライブラリ
#
# Author:: Ryohei Watanabe
# Version:: 1.0 2008-02-22
# Copyright:: Ryohei Watanabe
# License:: Rubyライセンスに準拠
#
#=== 使い方
#==== PNGをGIFに変換して保存
#   image = SimpleImage.from_file('sample.png')
#   image.to_gif
#   image.path = 'sample.gif'
#   image.save
#
#==== PNGをJPGに変換して保存
#   image = SimpleImage.from_file('sample.png')
#   image.to_jpg
#   image.quality = 60 # 画質を60に設定
#   image.path = 'sample.jpg'
#   image.save
#
#==== リサイズ
#   30x50にリサイズして、pngに変換して保存
#   image.resize(30, 50)
#   image.to_png
#   image.path = 'new.png'
#   image.save
#
#==== 切り取り
#   (0,30)から100x120の部分を切り取る
#   image.crop({
#     :x => 0, :y => 30,
#     :width => 100, :height => 120
#   })
# 
#==== 画像の中心を切り取る
#   中心から100x100の部分を切り取る
#   image.crop_center(100, 100)
# 
#==== 指定した座標に画像を重ねる
#   (0, 50)にsample.pngを合成
#   image.composite('sample.png', 0, 50)
#
#==== 中心に画像を重ねる
#   sample.pngを中心に合成
#   image.composite_center('sample.png')
#
#=== 開発履歴
#* 1.0 2008-02-22
#  * とりあえず作成してみた 
class SimpleImage
  DEFAULT_QUALITY = 95

  # path:: 保存先のパス
  # from_fileで生成された場合、読み込んだファイルのパスが設定される
  # from_blobで生成された場合は設定されないので、saveメソッドを実行する前に
  # pathに保存先のパスを設定しておく必要がある
  attr_accessor :path

  #=== ファイルからSimpleImageオブジェクトを生成する
  #
  #_path_ :: 画像ファイルのパス 
  #戻り値 :: SimpleImageオブジェクト
  def self.from_file(path)
    unless File.exist?(path)
      raise ArgumentError, "File Not Found:'#{path}'"
    end
    image = SimpleImage.new(Magick::Image.read(path).first)
    image.path = path
    image
  end
  
  #=== blobからSimpleImageオブジェクトを生成する
  #
  #_blob_ :: blobデータ
  #戻り値 :: SimpleImageオブジェクト
  def self.from_blob(blob)
    SimpleImage.new(Magick::Image.from_blob(blob).first)
  end
  
  #=== 現在のフォーマットを返す
  #
  #戻り値 :: 現在の画像フォーマット(JPEG,GIF,PNG)
  def format
    @image.format
  end
  
  #=== 画像の幅
  #
  #戻り値 :: 画像の幅
  def width
    @image.columns
  end

  #=== 画像の高さ
  #
  #戻り値 :: 画像の高さ  
  def height
    @image.rows
  end

  #=== 画像データ(blog)を返す
  #
  #戻り値 :: 画像データ(blob)
  def content
    @image.to_blob
  end

  #=== ContentTypeを返す
  #
  #戻り値 :: ContentType("image/png"など)
  def content_type
    "image/#{self.format.downcase}"
  end
  
  #=== 現在のフォーマットに対応する拡張子を返す
  # 現在設定されているpathとは関係なく画像フォーマットに対応する拡張子を返す
  # 例：
  # image = SimpleImage.from_file("test.jpg")
  # puts image.path ==> "test.jpg"
  # puts image.ext ==> "jpg"
  # image.to_png
  # puts image.ext ==> "png"
  # 
  #戻り値 :: 拡張子
  def ext
    case self.format
    when 'JPEG'
      return 'jpg'
    end

    self.format.downcase
  end
  
  #=== ファイル名を返す
  # @pathが定義されている場合のみ有効。@pathが無効な値などの場合nilを返す
  #
  #戻り値 :: ファイル名
  def filename
    unless @path
      return nil
    end
    File.basename(@path)
  end
  
  #=== 画質を設定する
  # JPEGで画像を保存する時にここで設定した値が使用される
  #
  #_quality_:: 1～100
  def quality=(quality)
    if quality.to_s =~ /^([0-9]+)$/ && (1 <= quality.to_i && quality.to_i <= 100)
      @quality = quality.to_i
    end
  end

  #=== 画質を返す
  #
  #戻り値 :: 画質(1～100)
  def quality
    @quality
  end

  #=== PNGに変換する
  def to_png
    unless @image.format == "PNG"
      @image.format = 'PNG' 
    end
  end

  #=== JPEGに変換する
  # to_jpegと同じ
  def to_jpg
    to_jpeg
  end
  
  #=== JPEGに変換する
  def to_jpeg
    unless @image.format == "JPEG"
      @image.format = 'JPEG'
      quality = @quality
      @image = Magick::Image.from_blob(@image.to_blob {self.quality = quality}).first
    end
  end

  #=== GIFに変換する  
  def to_gif
    unless @image.format == "GIF"
      @image.format = "GIF"
    end
  end

  #=== 指定した幅と高さの両方に合わせてリサイズする
  #
  #_width_ :: 幅
  #_height_ :: 高さ
  def resize_to_fit(width, height)
    @image = @image.resize_to_fit(width.to_i, height.to_i)
  end

  #=== リサイズする
  #
  #_width_ :: 変更後の幅
  #_height_ :: 変更後の高さ
  def resize(width, height)
    # パーセント指定対応
    if width.to_s =~ /^([0-9]+)%$/
      width = percent_to_pixel(self.width, width)
    end

    if height.to_s =~ /^([0-9]+)%$/
      height = percent_to_pixel(self.height, height)
    end
    
    @image = @image.resize(width.to_i, height.to_i)
  end

  #=== 幅に合わせてリサイズする
  #
  #_width_ :: 変更後の幅
  def resize_by_width(width)
    if width.to_s =~ /^([0-9]+)%$/
      width = percent_to_pixel(self.width, width)
    end
    height = (width.to_f * self.height.to_f) / self.width.to_f
    resize(width, height)
  end
  
  #=== 高さに合わせてリサイズする
  #
  #_height_ :: 変更後の高さ
  def resize_by_height(height)
    if height.to_s =~ /^([0-9]+)%$/
      height = percent_to_pixel(self.height, height)
    end
    width = (height.to_f * self.width.to_f) / self.height.to_f
    resize(width, height)
  end

  #=== 任意の座標から指定したサイズに切り抜く
  # 使用例: (0,30)の位置から100x50の画像を切り抜く
  # image = SimpleImage.from_file('sample.jpg')
  # image.crop({:x => 0, :y => 30, :width => 100, :height => 50})
  #
  #_opts_ :: オプション
  def crop(opts = {})
    opts = {
      :x => 0,
      :y => 0,
      :width => self.width,
      :height => self.height
    }.update opts
    
    @image = @image.crop(opts[:x], opts[:y], opts[:width], opts[:height], true)
  end

  #=== ファイルに保存する
  # pathメソッドで指定したパスに保存される
  # 
  # 例1： この場合はsample.pngが保存先として設定される
  # image = SimpleImage.from_file('sample.png')
  # image.save
  # 
  # 例2: pathメソッドで保存先をnew.pngに変更(別名保存)する
  # image = SimpleImage.from_file('sample.png')
  # image.path = 'new.png'
  # image.save
  # 
  # 例3: from_blobで生成した場合、pathを実行しないと保存先が設定されないため保存に失敗する
  # image = SimpleImage.from_blog(blob)
  # image.save これは失敗する
  # image.path = './sample.png' 保存先を指定する
  # image.save これは成功する
  # 
  #戻り値 :: 保存に成功した場合true、失敗時false
  def save
    unless @path
      return false
    end

    begin
      # RMagickでは拡張子がないと保存されない場合があるが、
      # 拡張子をつけずに保存したい場合もあるので、一時的に拡張子をつけて
      # 保存後に元に戻す
      
      # ファイル名に拡張子がついていない場合、拡張子をつける
      ext = format.downcase
      ext = "jpg" if ext == "jpeg"
      tmp_path = @path
      renamed = false
      pattern = Regexp.new("\\.#{ext}$")
      if tmp_path !~ pattern
        tmp_path += ".#{ext}"
        renamed = true
      end

      # 保存
      format = self.format
      quality = @quality
      @image.write(tmp_path) {
        if format == 'JPEG'
          self.quality = quality
        end
      }
      # ファイル名を元に戻す
      if renamed && File.exist?(tmp_path)
        File.rename(tmp_path, @path)
      end

      # 最終的にファイルがあれば保存成功とする
      return File.exist?(@path)
    rescue => e
      puts e.message
    end

    return false
  end
  
  #=== 画像を中心から指定したサイズに切り抜く
  # 例: 画像の中心から50x100の画像を切り抜く
  # image = SimpleImage.from_file('sample.gif')
  # image.crop_center(50, 100)
  #
  #_width_ :: 幅
  #_height_ :: 高さ
  def crop_center(width, height)
    @image = @image.crop(Magick::CenterGravity, width, height, true)
  end

  #=== 指定のフォーマットに変換する
  # PNG, JPEG, GIFへ変換するメソッド(to_png, to_jpeg, to_gif)を内部で呼んでいるだけ
  #
  #_format_ :: 変換先のフォーマット。PNG,JPEG,GIFのいずれかを指定する
  def change_format(format)
    format = format.to_s.upcase
    if format == 'JPG'
      format = 'JPEG'
    end
    format = format.gsub(/jpeg/, 'jpg')
    case format
    when 'JPEG'
      self.to_jpeg
    when 'GIF'
      self.to_gif
    when 'PNG'
      self.to_png
    end
  end
  
  #=== 指定したファイルを画像の任意の座標に合成する
  # 例: base.pngの(30, 50)にsample.pngを重ねる
  # image = SimpleImage.from_file('base.png')
  # image.composite('sample.png', 30, 50)
  #
  #_path_ :: 合成する画像ファイルのパス
  #_x_ :: 配置するx座標
  #_y_ :: 配置するy座標
  def composite(path, x, y)    
     begin
      src = Magick::Image.read(path).first
      # srcと自身のフォーマットを合わせる
      change_format(src.format)
      @image = @image.composite(src, x, y, Magick::OverCompositeOp)
    rescue Exception => e
      puts e.message
    end
  end
  
  #== 指定したファイル画像の中心に合成する
  # 例: base.pngの中心にsample.pngを重ねる
  # image = SimpleImage.from_file('base.png')
  # image.composite_center('sample.png')
  #
  #_path_ :: 合成する画像ファイルのパス
  def composite_center(path)
    begin
      src = Magick::Image.read(path).first
      # srcと自身のフォーマットを合わせる
      change_format(src.format)
      @image = @image.composite(src, Magick::CenterGravity, Magick::OverCompositeOp)
    rescue Exception => e
      puts e.message
    end
  end

  def to_s
    info = Array.new
    info << "path=#{self.path}"
    info << "format=#{self.format}"
    info << "content_type=#{self.content_type}"
    info << "size=#{self.width}x#{self.height}"
    info << "datasize=#{self.content.size}bytes"
    if self.format == 'JPEG'
      info << "quality=#{self.quality}"
    end
    info << "filename=#{self.filename}"
    info.join(', ')
  end

  # コメントを設定する
  #
  #_comment_:: コメント
  def comment=(comment)
    @image['comment'] = comment
  end
  
  # コメントを返す
  #
  #戻り値:: コメント
  def comment
    @image['comment']
  end
  
private
  def initialize(image)
    @image = image
    @quality = DEFAULT_QUALITY
    return @image
  end
  
  #=== パーセントをpixelに直す
  # 
  #_pixel_:: 基準とするpixel
  #_percent_:: 変換するパーセント(80%などで指定)
  #戻り値 :: 変換したpixel
  def percent_to_pixel(pixel, percent)
    if percent.to_s =~ /^([0-9]+)%$/
      per = $1.to_i
      if per > 100
        per = 100
      end

      pixel = pixel.to_f * (per.to_f/100.0)
    end
    return pixel
  end

end
