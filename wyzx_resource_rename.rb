# # 使用方法
#
#   ruby script.rb csv文件 输入文件夹 输出文件夹
#
# ## csv格式例子：
#
# fn, book, unit, type
#
# a.jpg, 2, 1, pic
#
# b.mp4, 6, 2, video
#
# c.mp3, 3, 4, audio
#
# ## 工具行为
#
# 本脚本会根据csv文件提供的信息，按照约定规则，将输入文件夹中的所有文件复制到输出文件夹。
#
# 复制过程包括
#
#   1. 生成新文件名
#   2. 生成新的文件夹目录
#   3. 将文件复制到新的文件目录结构中，使用新文件名
#
# 举例：
#
# 上面csv中的例子在输出文件夹中会是类似如下的形式
#
# "out/audio/book_3/unit_4/c.mp3"
#
# "out/video/book_6/unit_4/b.mp4"
#
# "out/pic/book_2/unit_1/a.jpg"
#
#
# ## 注意
#
# 是**复制**而不是移动。因为输入文件夹中的文件可以对应多个输出文件夹中的文件。
#
# 举例： a.jpg 使用了两次，两次使用时用了不同的名字 b2_u1_a.jpg, b3_u2_b.jpg
#
#
# 对应的excel是
#
# fn, book, unit, type
#
# a.jpg, 2, 1, pic
#
# a.jpg, 3, 2, pic

require 'csv'
require 'FileUtils'

# namespace
module WyzxRename
  @debug = true

  module_function

  def go(h, in_dir, out_dir)
    @in, @out = in_dir, out_dir
    @filename = normalize_str h[:filename]
    @book = normalize_str h[:book]
    @unit = normalize_str h[:unit]
    @type = normalize_str h[:type]
    @newdir = assemble_new_dir
    o_fn = File.join @in, @filename
    n_fn = assemble_new_filename
    copy_to_new_folder o_fn, File.join(@newdir, n_fn)

    p @newdir if @debug
  end

  def normalize_str(s)
    s.strip.downcase
  end

  def assemble_new_dir
    File.join @out, @type, "book_#{@book}", "unit_#{@unit}"
  end

  def assemble_new_filename
    @filename
  end

  def normalize_filename
    @filename
  end

  def mkdir_if_not_exist
    FileUtils.mkdir_p @newdir unless File.exist? @newdir
  end

  def copy_to_new_folder(o, n)
    mkdir_if_not_exist
    FileUtils.cp o, n
  end
end

def main(csv, in_dir, out_dir)
  # 默认的converters: numeric 我们要的就是字符而不是数字
  CSV.table(csv, converters: nil).each do |e|
    WyzxRename.go e, in_dir, out_dir
  end
end

main ARGV[0] || 'rename.csv', ARGV[1] || 'in', ARGV[2] || 'out'
