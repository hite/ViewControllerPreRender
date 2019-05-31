#!/usr/bin/ruby
# -*- coding: UTF-8 -*-

categoryType = Hash.new

File.open("toBeCaclulate.txt", "r") do |file|  
    file.each_line do |line|  
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
if !typeArray.empty?
    sample = categoryType[typeArray.first]
    # 先输出 分类 tab
    puts typeArray.join("\t")
    for i in 0...sample.count do
        tabData = Array.new
        typeArray.each{ | key |
            dataOfType = categoryType[key]
            tabData.push(dataOfType[i].strip)
        }
        puts tabData.join("\t")
    end
end

avgArr = Array.new
categoryType.each do |key, arr| 
    sum = 0
    arr.map{ |item|
        sum = sum + item.to_f
    }
    avg = sum.to_f / arr.length
    avgArr.push(avg)
end
puts "Avg of #{categoryType.values.first.count}:"
puts avgArr.join("\t")
