// ceiling log function
// gives the minimum number of bits required to store 0 to size-1
// e.g. clog2(7) = 3, clog2(11) = clog2(16) = 4
function integer clog2(input integer size);
begin
	size = size - 1;
	for (clog2 = 1; size > 1; clog2 = clog2 + 1)
		size = size >> 1;
	end
endfunction
