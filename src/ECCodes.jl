module ECCodes

import Base: close,keys,getindex
export withmessages

const depfile = joinpath(dirname(@__FILE__), "..", "deps", "deps.jl")
if isfile(depfile)
    include(depfile)
else
    error("libeccodes not properly installed. Please run Pkg.build(\"ECCodes\")")
end


type GribFile
    file::Ptr{Void}
end

function GribFile(fname::String)
    f=ccall((:fopen,"libc"),Ptr{Void},(Cstring,Cstring),fname,"r")
    if f==C_NULL
        error("Can't open grib file $(fname).")
    end
    return GribFile(f)
end

function close(f::GribFile)
    if f.file!=C_NULL
        error=ccall((:fclose,"libc"),Cint,(Ptr{Void},),f.file)
        if error!=0
            error("Error $(error) when calling fclose.")
        end
        f.file=C_NULL
    end
end


type GribMessage
    handle::Ptr{Void}
end

valid(m::GribMessage)=m.handle!=C_NULL

function nextmessage(f::GribFile)
    error=Ref{Cint}(0)
    m=ccall((:codes_grib_handle_new_from_file,libeccodes),Ptr{Void},(Ptr{Void},Ptr{Void},Ref{Cint}),
            C_NULL,f.file,error)
    if error[]!=0
        error("Error $(error[]) when calling codes_grib_handle_new_from_file.")
    end
    return GribMessage(m)
end

function freemessage(m::GribMessage)
    if m.handle!=C_NULL
        ccall((:codes_handle_delete,libeccodes),Cint,(Ptr{Void},),m.handle)
        m.handle=C_NULL
    end
end

function keys(m::GribMessage,filter_flags=0)
    BADKEYS=["codedValues","values","bitmap"]
    
    r=String[]
    kiter=ccall((:codes_keys_iterator_new,libeccodes),Ptr{Void},(Ptr{Void},Culong,Ptr{Void}),
                m.handle,filter_flags,C_NULL)
    while true
        flag=ccall((:codes_keys_iterator_next,libeccodes),Cint,(Ptr{Void},),kiter)
        if flag==0
            break
        end
        kname=ccall((:codes_keys_iterator_get_name,libeccodes),Cstring,(Ptr{Void},),kiter)
        key=unsafe_string(kname)
        if !(key in BADKEYS)
            push!(r,key)
        end
    end
    error=ccall((:codes_keys_iterator_delete,libeccodes),Cint,(Ptr{Void},),kiter)
    if error!=0
        error("Error $(error) when calling codes_keys_iterator_delete.")
    end
    return r
end

function getstring(m::GribMessage,key::String)
    if !valid(m)
        error("Attempt to read from invalide message.")
    end
    length=Ref{Csize_t}(0)
    ccall((:codes_get_length,libeccodes),Cint,(Ptr{Void},Cstring,Ref{Csize_t}),
          m.handle,key,length)
    value=zeros(UInt8,length[]+1) # hopefully this buffer is big enough
    error=ccall((:codes_get_string,libeccodes),Cint,(Ptr{Void},Cstring,Ptr{UInt8},Ref{Csize_t}),
                m.handle,key,value,length)
    if error==-10
        throw(KeyError(key))
    end
    if error!=0
        error("Error $(error) when calling codes_get_string.")
    end
    return unsafe_string(pointer(value))
end

function data(m::GribMessage)
    error=Ref{Cint}(0)
    iterator=ccall((:codes_grib_iterator_new,libeccodes),Ptr{Void},(Ptr{Void},Culong,Ref{Cint}),m.handle,0,error)
    lat=Ref{Cdouble}(0)
    lon=Ref{Cdouble}(0)
    val=Ref{Cdouble}(0)
    lats=Float64[]
    lons=Float64[]
    vals=Float64[]
    while true
        ok=ccall((:codes_grib_iterator_next,libeccodes),Cint,(Ptr{Void},Ref{Cdouble},Ref{Cdouble},Ref{Cdouble}),
                 iterator,lat,lon,val)
        if ok==0
            break
        end
        push!(lats,lat[])
        push!(lons,lon[])
        push!(vals,val[])
    end
    ccall((:codes_grib_iterator_delete,libeccodes),Cint,(Ptr{Void},),iterator)
    return (lats,lons,vals)

end



getindex(m::GribMessage,key::String)=getstring(m,key)

function withmessages(dofunc,fname::String)
    f=GribFile(fname)
    while true
        m=nextmessage(f)
        if !valid(m)
            break
        end
        dofunc(m)
        freemessage(m)
    end
    close(f)
end

end 
