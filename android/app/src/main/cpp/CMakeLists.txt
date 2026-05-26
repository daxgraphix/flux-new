cmake_minimum_required(VERSION 3.10)

project(radio_library)

add_library(radio SHARED radio.c)

target_link_libraries(radio log)