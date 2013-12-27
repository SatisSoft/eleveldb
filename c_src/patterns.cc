/* 
 * File:   patterns.cc
 * Author: sidorov
 * 
 * Created on December 26, 2013, 3:17 PM
 */

#include "patterns.h"
#include "detail.hpp"

namespace eleveldb
{

Patterns::Patterns():
    m_Current(0)
{
}

Patterns::Patterns(ErlNifEnv* env, const ERL_NIF_TERM& src):
    m_Current(0)
{
    if (enif_is_list(env, src))
    {
        unsigned len;
        enif_get_list_length(env, src, &len);
        m_Data.reserve(len);
        
        ERL_NIF_TERM tail = src;
        for (unsigned k = 0; k < len; ++k)
        {
            ERL_NIF_TERM head;
            enif_get_list_cell(env, tail, &head, &tail);
            assert(enif_is_tuple(env, head));
            int arity;
            const ERL_NIF_TERM* values;
            enif_get_tuple(env, head, &arity, &values);
            assert(arity = 2);
            const std::string start = get_bin_value(env, values[0]);
            const std::string end = get_bin_value(env, values[1]);
            m_Data.push_back(std::make_pair(start, end));
        }
    }
}

std::string Patterns::get_bin_value(ErlNifEnv* env, ERL_NIF_TERM binary)
{
    assert(enif_is_binary(env, binary));
    ErlNifBinary key;
    enif_inspect_binary(env, binary, &key);
    return std::string(reinterpret_cast<char*>(key.data), key.size);
}

leveldb::Slice Patterns::first()
{
    assert(!is_null());
    m_Current = 0;
    return m_Data[0].first;
}

leveldb::Slice Patterns::last()
{
    assert(!is_null());
    m_Current = m_Data.size() - 1;
    return m_Data[m_Current].second;
}

leveldb::Slice Patterns::adjust_forward(const leveldb::Slice& src)
{
    
    //while: [ _, second] ... src ... [smth...]
    for (; m_Current < m_Data.size() && src.compare(leveldb::Slice(m_Data[m_Current].second)) > 0; ++m_Current);
    
    if (m_Current == m_Data.size()) 
    {
        //we are out of lack to find good pattern. Src is tooo far ahead. Giving up
        return leveldb::Slice();
    }
    else 
    {
        if (src.compare(m_Data[m_Current].first) >= 0)
        {
            //src >= first (and src <= last by prev check)
            //we are inside the interval
            return src;
        }
        else 
        {
            //src is before some interval
            return leveldb::Slice(m_Data[m_Current].first);
        }
    }
}

PatternsWorkHolder::PatternsWorkHolder(PatternsPersistentHolder& persistentStorage):
    p(persistentStorage.take()),
    persistent(persistentStorage)
{
    assert(p.get() != 0);
}

PatternsWorkHolder::~PatternsWorkHolder()
{
    if (persistent.return_back(p.get()))
    {
        p.release();
    }
}

PatternsPersistentHolder::PatternsPersistentHolder():
    p(new volatile Patterns())
{
}

Patterns* PatternsPersistentHolder::take()
{
    Patterns* ptr = 0;
    do
    {
        ptr = const_cast<Patterns*>(p);
    } while (!compare_and_swap(&p, ptr, static_cast<Patterns*>(0)));
    assert(ptr != 0);
    return ptr;
}

void PatternsPersistentHolder::put(const Patterns& patterns)
{
    
    Patterns* newPtr = new Patterns(patterns);
    Patterns* oldPtr = 0;
    do
    {
        oldPtr = const_cast<Patterns*>(p);
    } while (!compare_and_swap(&p, oldPtr, newPtr));
    delete oldPtr;
}

bool PatternsPersistentHolder::return_back(Patterns* patterns)
{
    return compare_and_swap(&p, static_cast<Patterns*>(0), patterns);
}

PatternsPersistentHolder::~PatternsPersistentHolder()
{
    delete p;
}




}
