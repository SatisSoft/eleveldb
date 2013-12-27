/* 
 * File:   patterns.h
 * Author: sidorov
 *
 * Created on December 26, 2013, 3:17 PM
 */

#ifndef PATTERNS_H
#define	PATTERNS_H

#include "leveldb/slice.h"
#include <erl_nif.h>
#include <vector>
#include <utility>
#include <string>
#include <memory>

namespace eleveldb
{

class Patterns 
{
public:
    Patterns();
    Patterns(ErlNifEnv* env, const ERL_NIF_TERM& src);
    
    bool is_null() const { return m_Data.empty(); } 
    
    leveldb::Slice adjust_forward(const leveldb::Slice& src);
    
    leveldb::Slice first();
    leveldb::Slice last();
    
private:
    std::vector<std::pair<std::string, std::string> > m_Data;
    size_t m_Current;
    
    static std::string get_bin_value(ErlNifEnv* env, ERL_NIF_TERM binary);
};

class PatternsPersistentHolder;
class PatternsWorkHolder
{
public:
    PatternsWorkHolder(PatternsPersistentHolder& persistentStorage);
    Patterns* operator->() { return p.get(); }
    ~PatternsWorkHolder();
    
private:
    PatternsWorkHolder(PatternsWorkHolder&); //disable copy
    std::auto_ptr<Patterns> p;
    PatternsPersistentHolder& persistent;
};

class PatternsPersistentHolder
{
public:
    PatternsPersistentHolder();
    Patterns* take();
    void put(const Patterns& patterns);
    bool return_back(Patterns* patterns);
    ~PatternsPersistentHolder();
    
private:
    volatile Patterns* p;
};

}

#endif	/* PATTERNS_H */

