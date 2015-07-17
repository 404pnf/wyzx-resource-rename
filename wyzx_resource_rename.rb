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


## 实际csv举例

# Unit,Section,Sub-section,Task,Activity / Step,Question,原文件名,新文件名
#
# 1,Listening to the world (2),Sharing (1),1,,,U1_1_1.mp4,u1_2.1.1.mp4
#
# 1,Listening to the world (2),Sharing (1),2,,,,
#
# 1,Listening to the world (2),Sharing (1),3,,,,

# ## 规则补充
#
# 说明： 1 基于新视野视听说的层级分析，Section和Sub-section对应的层级数字是固定的，具体可见各Section和Sub-section标题文字后的数字。
#       2 如果文件名中出现某一个中间层级为空的情况，那么该层级的数字表现为0
#       3 如果某层级有多个同级别的文件时，则用a、b等英文字母来区别


require 'csv'
require 'FileUtils'
#require 'did_you_mean'

# namespace
module WyzxRename
  debug = true

  module_function

  # >> db.headers
  # => [:unit, :section, :subsection, :task, :activity_step, :question, :orig_filename, :new_filename]
  def go(h, in_dir, out_dir)
    # 清理csv中的字符串
    # 删除收尾多余空格，转换nil，判断去除多余空格后是否为空
    h = h.each_with_object({}) do |(k, v), a|
      if k == :orig_filename  # 原始文件名不应该改变，否则它也变成只剩数字了
        a[k] = v.strip
      else
        a[k] = normalize_str(v)
      end
    end
    unit =  h[:unit]
    section = h[:section]
    subsection =  h[:subsection]
    task =  h[:task]
    activity_step =  h[:activity_step]
    question =  h[:question]
    orig_filename = h[:orig_filename]
    suffix = File.extname(orig_filename)

    # new_filename规则
    # 如果文件名中出现某一个中间层级为空的情况，那么该层级的数字表现为0
    new_fn_arr = [unit, section, subsection, task, activity_step, question]
    # 去掉末尾连续出现的空白。
    # 借用数组的drop_while
    # >> a = [ ' ', ' ', 'ab']
    # => [" ", " ", "ab"]
    # >> a.drop_while { |e| e == ' ' }
    # => ["ab"]
    new_fn_without_suffix = new_fn_arr.reverse
      .drop_while { |e| e == ' '}
      .reverse
      .map { |e| e == ' ' ? 0 : e } # 某一个中间层级为空，补0
      .join('_')
    new_filename = "#{new_fn_without_suffix}#{suffix}"
    p new_filename


    orig_file_with_path = File.join in_dir, orig_filename
    new_file_with_path = File.join out_dir, new_filename

  end

  # 清理csv中的字符串
  # 1. 删除收尾多余空格
  # 2. 转换nil
  # 3. 判断去除多余空格后是否为空
  # 4. 从文本中捕获数字和3a这种文本
  #
  # case A: csv内容为空是，会解析为nil，将nil转为一个空格
  # case B: csv内容只是一些空格，我们也应该先清除这些空格看看是否有实际内容。没有的话，将其设定为一个空格。
  # case C: csv内容有多余的注释内容 Listening to the world (2), 只保留数字
  # case D: 需要保留 3a 3b 这种的a和b
  def normalize_str(s)
    s = s || ' '
    ss = s.match(/\d[0-9a-z]?/).to_s
    if ss.strip() == ''
        ' '
    else
      ss.strip()
    end
  end

  def mkdir_if_not_exist(newdir)
    FileUtils.mkdir_p newdir unless File.exist? newdir
  end

  def copy_to_new_folder(o, n)
    FileUtils.cp o, n
  end
end

def main(csv, in_dir, out_dir)
  p "输入目录是 #{in_dir}。输出目录是 #{out_dir}"
  # 默认的converters: numeric 我们要的就是字符而不是数字
  CSV.table(csv, converters: nil).each do |e|
    WyzxRename.go e, in_dir, out_dir
  end
end

main ARGV[0] || 'rename.csv', ARGV[1] || 'in', ARGV[2] || 'out'
