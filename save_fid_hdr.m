function bytes_written=save_fid_hdr(the_file,hdr)
% function bytes_written=save_fid_hdr(hdr,path)
% Taking a hdr struct from load_fid_hdr, save the agilent hdr back to some
% path.
% hdr_struct has fields in order of proper type, so this function can
% blindly write

if ischar(the_file) && exist(fileparts(the_file),'dir')
    if ~exist(the_file,'file')
        mode='w';
    else
        mode='r+';
    end
    fid=fopen(the_file,mode,'b');
    if fid<0
        error('Open failed %s',the_file)
    end
    close_on_quit=1;
else
    fid=the_file;
    close_on_quit=0;
end
bytes_written=0;

hdr_fields=fieldnames(hdr);
fidx=1;
while fidx<=numel(hdr_fields)
    value=hdr.(hdr_fields{fidx});
    if ~isstruct(value)&& ~islogical(value)
        count=fwrite(fid,value,class(value));
        i=whos('value');
        bytes_written=bytes_written+i.bytes;
        assert(count==numel(value),sprintf('ERROR on write %s',hdr_fields{fidx}));
    elseif islogical(value)
        %% repack bits into appropriate unsigned integer 
        % expectation would be that every unpacked status int is a single
        % structure. This'll support up to 64 of them before it forces a
        % separation.
        st_idx=fidx;
        eidx=fidx;
        log_vals=0;
        bit_count=0;
        while(islogical(hdr.(hdr_fields{eidx})) ...
                && eidx<numel(hdr_fields) ...
                && bit_count < 64 )
            log_vals=log_vals+1;
            eidx=eidx+1;
            bit_count=eidx-st_idx+1;
        end
        % forces power of 2 parts for the bit_count, eg, 
        % 2^ 3,4,5,6  for 8,16,32,64 bits.
        if mod(log2(bit_count),1)~= 0 % ~mod(bit_count,8)
            error('Uneven bit->byte count, there was probably an error on load');
        else
            packed_bits=eval(sprintf('uint%i(0);',bit_count));
            for fidx=st_idx:eidx
                if( hdr.(hdr_fields{fidx}) )
                    bit=fidx-st_idx+1;
                    packed_bits=bitset(packed_bits,bit);
                end
            end
            value=packed_bits;
            count=fwrite(fid,value,class(value));
            i=whos('value');
            bytes_written=bytes_written+i.bytes;
            assert(count==numel(value),sprintf('ERROR on write %s',hdr_fields{fidx}));
        end
    elseif isstruct(value)
        bytes_written=bytes_written+save_fid_hdr(fid,value);
    else
        error('Unexpected');
    end
    fidx=fidx+1;
end
if close_on_quit
    fclose(fid);
end
       
