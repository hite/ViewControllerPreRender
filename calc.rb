#!/usr/bin/ruby
# -*- coding: UTF-8 -*-

categoryType = Hash.new

File.open("toBeCaclulate.txt", "r") do |file|  
    file.each_line do |line|  
        line.delete_prefix!("[Timing] ")
        if line.start_with?("//") # comment
            next
        end
        if line.length == 0
            puts "Empty line"
        else
            _arr = line.split("=")
            if _arr.count == 2
                key = _arr.at(0).strip
                val = _arr.at(1).strip
                if categoryType[key] == nil; then
                    categoryType[key] = Array.new
                end
                categoryType[key].push(val)
            else
                puts "wrong format, skip it,#{line}"
            end
        end
        
    end  
end 

# 循环输出

typeArray = categoryType.keys
markdown_sep = '  |  '
if !typeArray.empty?
    sample = categoryType[typeArray.first]
    # 先输出 分类 tab
    puts typeArray.join(markdown_sep)
    # 分隔符，markdown 格式
    sepData = Array.new
    for i in 0...typeArray.count do
        sepData.push('---')
    end
    puts sepData.join("|")
    # 具体数据
    for i in 0...sample.count do
        tabData = Array.new
        typeArray.each{ | key |
            dataOfType = categoryType[key]
            tabData.push(dataOfType[i].strip)
        }
        puts tabData.join(markdown_sep)
    end

end

avgArr = Array.new
categoryType.each do |key, arr| 
    sum = 0
    arr.map{ |item|
        sum = sum + item.to_f
    }
    avg = sum.to_f / arr.length
    avgArr.push(avg.round(4))
end
puts "Avg of #{categoryType.values.first.count}:"
puts avgArr.join(markdown_sep)
