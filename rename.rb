#!/usr/bin/env ruby

# # 使用方法
#
#   ruby script.rb csv文件 输入文件夹 输出文件夹
#
# ## 默认值
#
# 默认csv文件名为 rename.csv 。 默认输入输出目录分别为 in, out。
#
# ## csv格式举例：
#
#       fn, book, unit, type
#       a.jpg, 2, 1, pic
#       b.mp4, 6, 2, video
#       c.mp3, 3, 4, audio
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
#     "out/audio/book_3/unit_4/c.mp3"
#     "out/video/book_6/unit_4/b.mp4"
#     "out/pic/book_2/unit_1/a.jpg"
#
#
# ## 注意
#
# 是**复制**而不是移动。因为输入文件夹中的文件可以对应多个输出文件夹中的文件。
#
# 举例： a.jpg 使用了两次，两次使用时用了不同的名字 b2_u1_a.jpg, b3_u2_b.jpg
#
# ## 实际csv举例
#
#      "book","Unit","Section","Sub-section","Task","Activity Step","Question","orig_filename"
#      1,1,2,1,1,,,"U1_1_1.mp4"
#      1,1,2,1,2,,,"U1_1_1b.mp4"
#      1,1,2,1,3,,,"U1_1_1c.mp4"
#      1,1,2,1,"3a",,,"u1_2.1.3_a.jpg"
#      1,1,2,1,"3b",,,"u1_2.1.3_b.jpg"
#      1,1,2,1,"3c",,,"u1_2.1.3_c.jpg"
#
# ## 规则补充
#
# 说明：
# 1. 基于新视野视听说的层级分析，Section和Sub-section对应的层级数字是固定的，具体可见各Section和Sub-section标题文字后的数字。
# 1. 如果文件名中出现某一个中间层级为空的情况，那么该层级的数字表现为0
# 1. 如果文件末尾连续出现空的层级，在新文件名中忽略它们
# 1. 如果某层级有多个同级别的文件时，则用a、b等英文字母来区别

require 'csv'
require 'FileUtils'
# require 'did_you_mean'

# namespace
module WyzxRename
  @debug = false
  @verbose = true
  USAGE = <<-EOF
    简单说明使用方法：

    1. 请将csv文件命名为rename.csv
    2. 将要重命名的文件全部放在 in 文件夹内
    3. 双击 rename.rb

    详细说明

    # 使用说明

    1. 打开example_rename.csv文件。
    2. 删除之前的数据，按要求填入新数据。
    3. 复制 example_rename.csv 到 rename.csv，覆盖之前的rename.csv。
    4. 双击 rename.rb
    5. 如果有问题，屏幕会提示问题出现在哪里。请做相应修改。
    6. 如果一切正常，你回看到 Everything is OK!. Find your new files at << out >> directory.
    6. 还是搞不定，联系 9679 。请发问题截图。

    完整命令行参数：ruby csv文件名.csv 输入文件夹 输出文件夹

  EOF

  TYPE = {
    '.jpg' => 'image',
    '.jpeg' => 'image',
    '.png' => 'image',
    '.mp3' => 'audio',
    '.mp4' => 'video'
  }

  # 为了让counter从'a'开始。我们要找到'a'前面是哪个字符。
  #     >> 'a'.ord
  #     => 97
  #     >> 96.chr
  #     => "`" # backtick
  #     >> '`'.next
  #     => "a"
  #     >> '`'.next.next
  #     => "b"
  COUNTER = lambda do
    id = '`'
    -> { id = id.next }
  end

  module_function

  # 默认的converters: numeric 我们要的就是字符而不是数字
  # 将in_dir和out_dir也放到数据中，方便后面使用。
  def main(csv, in_dir, out_dir)
    puts "\nInput dir is <<#{in_dir}>>. Output dir is <<#{out_dir}>>\n\n"
    d = CSV.table(csv, converters: nil).map(&:to_h)
    puts d[0].keys if @debug
    d1 = add_input_output_dir d, in_dir, out_dir
    data = add_extra_id d1
    orig_files = data.map { |e| File.join e[:in_dir], e[:orig_filename] }
    exit if find_missing_files(orig_files) || check_suffix(orig_files)
    @data = data.dup
    data.each_with_index { |e, i| go e, i }
    puts "\nDone. Check #{out_dir} directory.\n\n"
    options = { headers: @data.first.keys.delete_if { |k| [:extra_id, :out_dir, :in_dir].member? k },
                force_quotes: true,
                write_headers: true
              }
    CSV.open("rename-#{Time.now.strftime('%Y-%m-%d')}.csv", 'w', options) do |c|
      @data.each do |h|
        hh = h.delete_if { |k| [:extra_id, :out_dir, :in_dir].member? k }
        c << hh.values
      end
    end
  end

  def add_input_output_dir(d, in_dir, out_dir)
    d.map do |e|
      e[:in_dir] = in_dir
      e[:out_dir] = out_dir
      e
    end
  end

  # keys of csv
  # book unit section subsection task activity_step question #\
  # 还需要加上suffix作为键。
  # 否则会误判级别一样但不是同一类型文件的两个文件为重名啦。
  #
  # 误判举例
  #
  #     下面几个文件有相同的级别层次，该级别为 1_1_4_2_1
  #     ["1", "1", "4", "2", "1", nil, nil, nil]
  #     "U1_3_3_1.mp3"
  #     "u1_4.2.1_1.jpg"
  #
  # 如果某个键出现了多个文件，那么直接根据现有规则重命名就会出现重名的情况，
  # 我们去给相同键下的这些记录一次增加一个extra_id，从'1'开始。
  # 可用 each_with_index，再将数字转为字母。
  def add_extra_id(d)
    dd = d.group_by do |e|
      suffix = File.extname e[:orig_filename]
      k = e.values_at(:book, :unit, :section, :subsection,
                      :task, :activity_step, :question
          )
      k.push suffix
    end

    extra = dd.select { |_, v| v.size > 1 }
    puts extra.size if @debug
    extra.each do |k, v|
      puts "\n下面几个文件有相同的级别层次，该级别为 #{k.join('_').gsub(/_+$/, '')} " if @debug
      p k if @debug
      v.each { |e| p e[:orig_filename] if @debug }
    end

    # 这里因为mutate了e，因此，with_id才能得到改变后的值。
    # 否则，each的语义是没有复制功能的，只不过最后返回extra本身。
    # 碰巧把extra赋值with_id。
    #
    # 这里还是应该修改为reduce。
    with_id = extra.each do |_, v|
      c = (self::COUNTER).call
      v.each do |e|
        e[:extra_id] = c.call
      end
    end

    db = dd.merge(with_id)
         .values
         .reduce([]) { |a, e| a.concat e }
    puts db.size if @debug
    db
  end

  def find_missing_files(a)
    missing_files = a.map { |e | [File.exist?(e), e] }
                    .select { |e| e[0] == false }
                    .map { |e| e[1] }
    msg = <<-EOF
      ========================
      Missing following files:
      ========================
    EOF
    report_error(msg, missing_files) unless missing_files.empty?
  end

  def check_suffix(a)
    # ["in/U1_1_1.mp4", "in/U1_1_1b.mp4", ...
    # p a
    wrong_suffix = a.map { |e| [self::TYPE[File.extname e], e] }
                   .select { |e| e[0].nil? }
                   .map { |e| e[1] }
    msg = <<-EOF
      =============================
      Wrong suffix. Check spelling?
      =============================
    EOF
    report_error(msg, wrong_suffix) unless wrong_suffix.empty?
  end

  # 返回 true， 表明报错函数被调用了。
  # 方便之前的函数知道到底有没有错误发现错误并报告给用户。
  # 举例：
  #
  #     status = check_suffix(a)
  #     exit if status
  #
  # 如果check_suffix发现了错误并嗲用了report_error，则程序退出。
  def report_error(msg, a)
    puts msg
    a.each { |e| puts "      #{e}" }
    true
  end

  #      >> csv headers
  #      => [:book, :type, :unit, :section, :subsection, :task, :activity_step, :question, :orig_filename, :new_filename]
  # 生成测试数据
  # system("mkdir in; cd in; touch #{@orig_filename}")
  def go(h, idx)
    h = h.each_with_object({}) { |(k, v), a| a[k] = normalize_str(v) }
    @book, @unit, @section, @subsection,
    @task, @activity_step, @question,
    @orig_filename, @in_dir, @out_dir, @extra_id = h.values_at(
        :book, :unit, :section, :subsection,
        :task, :activity_step, :question,
        :orig_filename, :in_dir, :out_dir, :extra_id
    )
    suffix = File.extname(@orig_filename)
    @type = self::TYPE[suffix.downcase]

    new_filename = "#{assemble_new_filename}#{suffix.downcase}"
    newdir = File.join h[:out_dir], "book_#{@book}", "unit_#{@unit}", @type

    mkdir_if_not_exist(newdir)
    copy_to_new_folder(File.join(@in_dir, @orig_filename), (File.join newdir, new_filename))
    @data[idx][:new_name] = new_filename
    @data[idx][:new_dir] = newdir
  end

  # 清理csv中的字符串
  # 1. 删除首尾多余空格
  # 2. 转换nil
  def normalize_str(s)
    s ||= '' # 处理s是nil的情况
    if s.strip == ''
      false
    else
      s.strip
    end
  end

  # 如果文件末尾连续出现空的层级，在新文件名中忽略它们。
  # 借用数组的drop_while。
  #       >> a = [ false, false, 'ab']
  #       >> a.drop_while(&:!)
  #       => ["ab"]
  def assemble_new_filename
    arr = ["b#{@book}", "u#{@unit}", @section, @subsection,
           @task, @activity_step, @question]
    s = arr.reverse
        .drop_while(&:!)
        .reverse
        .map { |e| e ? e : 0 } # 中间层级为空，补0
        .join('_')
    if @extra_id
      puts "#{@orig_filename} 的新名字是 #{s}#{@extra_id} \n\n" if @debug
      "#{s}#{@extra_id}"
    else
      s
    end
  end

  def mkdir_if_not_exist(newdir)
    FileUtils.mkdir_p newdir unless File.exist? newdir
  end

  def copy_to_new_folder(o, n)
    p "COPY FILE #{o} TO #{n}" if @verbose
    FileUtils.cp o, n
  end
end

if ARGV[0] == 'help'
  puts WyzxRename::USAGE
else
  WyzxRename.main ARGV[0] || 'rename.csv', ARGV[1] || 'in', ARGV[2] || 'out'
end
