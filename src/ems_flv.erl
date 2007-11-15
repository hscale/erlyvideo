%%% @author     Roberto Saccon <rsaccon@gmail.com> [http://rsaccon.com]
%%% @author     Stuart Jackson <simpleenigmainc@gmail.com> [http://erlsoft.org]
%%% @author     Luke Hubbard <luke@codegent.com> [http://www.codegent.com]
%%% @copyright  2007 Luke Hubbard, Stuart Jackson, Roberto Saccon
%%% @doc        RTMP encoding/decoding and command handling module
%%% @reference  See <a href="http://erlyvideo.googlecode.com" target="_top">http://erlyvideo.googlecode.com</a> for more information
%%% @end
%%%
%%%
%%% The MIT License
%%%
%%% Copyright (c) 2007 Luke Hubbard, Stuart Jackson, Roberto Saccon
%%%
%%% Permission is hereby granted, free of charge, to any person obtaining a copy
%%% of this software and associated documentation files (the "Software"), to deal
%%% in the Software without restriction, including without limitation the rights
%%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%%% copies of the Software, and to permit persons to whom the Software is
%%% furnished to do so, subject to the following conditions:
%%%
%%% The above copyright notice and this permission notice shall be included in
%%% all copies or substantial portions of the Software.
%%%
%%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
%%% THE SOFTWARE.
%%%
%%%---------------------------------------------------------------------------------------
-module(ems_flv).
-author('rsaccon@gmail.com').
-author('simpleenigmainc@gmail.com').
-author('luke@codegent.com').
-include("../include/ems.hrl").

-export([read_header/1,read_tag/2,to_tag/2,header/1, parse_meta/1]).

read_header(IoDev) -> 
    case file:read(IoDev, ?FLV_HEADER_LENGTH) of
        {ok, Data} -> 

			{ok, iolist_size(Data), header(Data)};
        eof -> {error, unexpected_eof};
        {error, Reason} -> {error, Reason}           
    end.


read_tag(IoDev, Pos) ->
	case file:pread(IoDev,Pos, ?FLV_PREV_TAG_SIZE_LENGTH + ?FLV_TAG_HEADER_LENGTH) of
		{ok, IoList} ->
			case iolist_to_binary(IoList) of
			  	<<PrevTagSize:32/integer,Type:8,BodyLength:24,TimeStamp:24,TimeStampExt:8,StreamId:24>> ->				
					case file:pread(IoDev, Pos + ?FLV_PREV_TAG_SIZE_LENGTH + ?FLV_TAG_HEADER_LENGTH, BodyLength) of
						{ok,IoList2} -> 
						    <<TimeStampAbs:32>> = <<TimeStampExt:8, TimeStamp:24>>,
							{ok, #flv_tag{prev_tag_size = PrevTagSize,
					         			  type          = Type,
							 			  body_length   = BodyLength,
							 			  timestamp_abs = TimeStampAbs,
							 			  streamid      = StreamId,
							 			  pos           = Pos,
							   			  nextpos       = Pos + ?FLV_PREV_TAG_SIZE_LENGTH + ?FLV_TAG_HEADER_LENGTH + BodyLength,
							 			  body          = iolist_to_binary(IoList2)}};
						eof -> 
							{ok, done};
						{error, Reason} -> 
							{error, Reason}
					end;
				_ ->
					{error, unexpected_eof}
			end;		
        eof -> 
			{error, unexpected_eof};
        {error, Reason} -> 
			{error, Reason}
	end.


header(#flv_header{version = Version, audio = Audio, video = Video} = FLVHeader) when is_record(FLVHeader,flv_header) -> 
	Reserved = 0,
	Offset = 9,
	PrevTag = 0,
	<<70,76,86,Version:8,Reserved:5,Audio:1,Reserved:1,Video:1,Offset:32,PrevTag:32>>;
header(Bin) when is_binary(Bin) ->
	<<70,76,86, Ver:8, _:5, Audio:1, _:1, Video:1, 0,0,0,9>> = Bin,
	#flv_header{version=Ver,audio=Audio,video=Video};
header(IoList) when is_list(IoList) -> header(iolist_to_binary(IoList)).
		
	
to_tag(#channel{msg = Msg,timestamp = FullTimeStamp, type = Type, stream = StreamId} = Channel, PrevTimeStamp) when is_record(Channel,channel) ->
	BodyLength = size(Msg),	
	{TimeStampExt, TimeStamp} = case PrevTimeStamp of
		<<TimeStampExt1:8,TimeStamp1:32>> -> 
			{TimeStampExt1, TimeStamp1};
		_ ->
			{0, PrevTimeStamp}
	end,			
	PrevTagSize = size(Msg) + 11,
	{<<Type:8,BodyLength:24,TimeStamp:24,TimeStampExt:8,StreamId:24,Msg/binary,PrevTagSize:32>>,
	 FullTimeStamp + PrevTimeStamp}.


parse_meta(Bin) ->
	file:write_file("/sfe/temp/meta.txt",Bin),
	?D(Bin),
	{Type,String,Next} = ems_amf:parse(Bin),
%	?D(String),
%	?D(Next),
	{Type,Array,_Next} = ems_amf:parse(Next),
	{String,Array}.
	


















