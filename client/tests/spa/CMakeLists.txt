cmake_minimum_required(VERSION 3.25)
project(ColdwireSpaTest LANGUAGES CXX)

find_package(Qt6 REQUIRED COMPONENTS Core Network)
set(CMAKE_AUTOMOC ON)
add_executable(coldwire-spa-test
    main.cpp
    ../../core/utils/spaAdmission.cpp
    ../../core/models/protocols/awgProtocolConfig.cpp
    ../../core/protocols/protocolUtils.cpp
    ../../core/utils/protocolEnum.h
)
target_compile_features(coldwire-spa-test PRIVATE cxx_std_17)
target_include_directories(coldwire-spa-test PRIVATE ../..)
target_link_libraries(coldwire-spa-test PRIVATE Qt6::Core Qt6::Network)
enable_testing()
add_test(NAME preserve_awg_spa_profile COMMAND coldwire-spa-test)
