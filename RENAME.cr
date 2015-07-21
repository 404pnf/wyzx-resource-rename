require "csv"
require "dir"

module Rename
  extend self

  def read_csv(file)
    s =  File.read file
    csv = CSV.parse s
    header = csv[0]
    data = csv[1..csv.length]
    row_with_header = data.map { |e| header.zip(e).to_h }
    row_with_header.each do |e|
      process(e)
    end
  end

  Dir.mkdir_p("a/b/c") unless Dir.exists?("a/b/c")

  def process(hsh)
    out_dir = "out"
    in_dir = "in"
    h = sanitize_data(hsh)
    book, type, unit, section, subsection, task, activity_step, question, orig_filename = h.values
    suffix = File.extname(orig_filename)
    # 生成测试数据
    # system("mkdir in; cd in; touch #{orig_filename}")

    # 根据规则拼出新的文件名
    new_fn_arr = [unit, section, subsection, task, activity_step, question]
    new_fn_without_suffix = assemble_new_filename(new_fn_arr)
    new_filename = "#{new_fn_without_suffix}#{suffix}"

    newdir = File.join out_dir, "book_#{book}", type, "unit_#{unit}"
    mkdir_if_not_exist(newdir)

    old_file_fullpath = File.join in_dir, orig_filename
    new_file_fullpath = File.join newdir, new_filename
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
