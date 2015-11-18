#!/usr/bin/env ruby

# # 直接根据规则重命名文件

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
#       suffix, orig_filename
#       suffix1, dirA/a.mp3
#       suffix2 with space, dirB/b.wmv
#
# ## 工具行为
#
# 本脚本会根据csv文件提供的信息，按照约定规则，将输入文件夹中的所有文件重命名。
#
# 过程包括
#
#   1. 获取原始文件名，过滤掉目录
#   2. 拼装新的文件名
#   3. 重命名文件
#
# 举例：
#
# 上面csv中的例子在输出文件夹中会是类似如下的形式
#
#     "dirA/a_suffix1.mp3"
#     "dirB/b_suffix2_with_space.wmv"
#

require 'csv'
require 'FileUtils'
require 'pp'
# require 'did_you_mean'

# namespace
module WyzxRename
  @debug = true
  @verbose = true
  USAGE = <<-EOF
    简单说明使用方法：

    1. 请将csv文件命名为rename.csv
    2. 根据规则填写csv
    3. 双击 rename.rb
    4. 还是搞不定，联系 9679 。请发问题截图。

    完整命令行参数：ruby csv文件名.csv 输入文件夹 输出文件夹

  EOF

  module_function

  # 默认的converters: numeric 我们要的就是字符而不是数字
  # 将in_dir和out_dir也放到数据中，方便后面使用。
  def main(csv, in_dir, out)
    Dir.mkdir(out) unless File.exist?(out)
    puts "\nInput dir is <<#{in_dir}>>. Output dir is <<>#{out}> \n\n"
    d = CSV.table(csv, converters: nil).map(&:to_h)
    puts d[0].keys if @debug
    pp d if @debug
    files = d.reject { |e| File.directory? e[:orig_filename].strip } # 过滤掉目录
    files.each do |e|
      new_filename = File.join "#{out}", "#{make_new_file_name e}"
      FileUtils.mkdir_p File.dirname(new_filename)
      FileUtils.cp e[:orig_filename].strip, new_filename, verbose: true #, noop: true
    end
  end

  def make_new_file_name(e)
    e[:orig_filename].strip!
    e[:suffix].strip!
    extenstion_name = File.extname e[:orig_filename]
    dir_name = File.dirname e[:orig_filename]
    file_name = File.basename e[:orig_filename], extenstion_name
    safe_suffix = e[:suffix].empty? ? '' : '_' + normalize_str(e[:suffix]).gsub(/ +/, '_')
    new_filename = File.join dir_name, "#{file_name}#{safe_suffix}#{extenstion_name}"
    new_filename
  end

  # 清理csv中的字符串
  # 1. 删除首尾多余空格
  # 2. 转换nil为空白字符串，因为默认csv模块会把没有填的csv格子复制为符号nil
  def normalize_str(s)
    s ||= '' # 处理s是nil的情况
    s.strip
  end
end

if ARGV[0] == 'help'
  puts WyzxRename::USAGE
else
  WyzxRename.main ARGV[0] || 'lijin.csv', ARGV[1] || '.', ARGV[2] || 'out'
end
