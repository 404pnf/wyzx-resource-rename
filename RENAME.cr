require "csv"
require "dir"
# require 'file'

module Rename
  extend self

  def read_csv(file)
    s =  File.read file
    csv = CSV.parse s
    header = csv[0]
    data = csv[1..csv.length]
    row_with_header = data.map { |e| header.zip(e).to_h }
    # puts row_with_header
    row_with_header.each do |e|
      process(e)
    end
  end

  def report_missing_files(arr)
    arr.each do |e|
      puts "没有找到这个文件：#{e}。"
    end
    puts "请解决上述问题后再运行本工具。"
  end

  # Dir.mkdir_p("a/b/c") unless Dir.exists?("a/b/c")

  def process(hsh)
    out_dir = "out"
    in_dir = "in"
    type_name = {
      ".jpg" => "image",
      ".jpeg" => "image",
      ".png" => "image",
      ".mp3" => "audio",
      ".mp4" => "video"
    }

    h = sanitize_data(hsh)
    book, type, unit, section, subsection, task, activity_step, question, orig_filename = h.values

    # 生成测试数据
    # system("mkdir in; cd in; touch #{orig_filename}")

    suffix = File.extname(orig_filename)
    unless type_name.has_key?(suffix)
      raise "

        OMG。不知道这个后缀代表什么类型： #{suffix.downcase} 。
        请检查是否为拼写错误并修改一下吧。

        "
    end

    # 从文件后缀判断类习惯。该类型是组成新文件所在目录的元素之一。
    type = type_name[suffix.downcase]

    # 根据规则拼出新的文件名
    new_fn_arr = [unit, section, subsection, task, activity_step, question]
    new_fn_without_suffix = assemble_new_filename(new_fn_arr)
    new_filename = "#{new_fn_without_suffix}#{suffix}"

    newdir = File.join out_dir, "book_#{book}", type, "unit_#{unit}"
    mkdir_if_not_exist(newdir)

    old_file_fullpath = File.join in_dir, orig_filename
    new_file_fullpath = File.join newdir, new_filename

    unless File.exists?(old_file_fullpath)
      raise "

        OMG。没找到这个文件： #{orig_filename} 。
        请检查是否为拼写错误并修改一下吧。

        "
    end

    file_copy(old_file_fullpath, new_file_fullpath)
  end

  def file_copy(infile, outfile)
    puts "复制 #{infile} 到 #{outfile}"
    File.write(outfile, File.read(infile))
  end

  def sanitize_data(h)
    hh = {} of String => String
    h.each do |k|
      v = h[k].strip
      if v.empty?
        hh[k] = "false"
      else
        hh[k] = v
      end
    end
    hh
  end

  def assemble_new_filename(arr)
    # 如果文件末尾连续出现空的层级，在新文件名中忽略它们
    # ["1", "2", "1", "1", "false", "false"] => 1_2_1_1
    # ["1", "4", "1", "2", "false", "false", "false", "1"] => 1_4_1_2_0_0_0_1
    arr.join("_").gsub(/(_false)*$/, "").gsub(/false/, "0")
  end

  def mkdir_if_not_exist(newdir)
    Dir.mkdir_p newdir unless File.exists? newdir
  end

end

Rename.read_csv("rename.csv")
