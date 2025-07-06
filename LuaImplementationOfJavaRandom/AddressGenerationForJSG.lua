
local ccString = require "cc.strings"
local ccPretty = require "cc.pretty"
-- Cheers for https://github.com/MostAwesomeDude/java-random haveing written a python implementation of java random
-- Lua implementation of java string hash function
local function StringHash (StringToHash)
    local String_Hash = 0
    for i = 1, #StringToHash do
        --[[
        Java String Hashing is as follows
        We add the ascii number of a char multiplied by 31 to the power of the length of the string minus our current position in the string
        e.g if we have a string containing 'hi' 
        it would be the ascii number of h * 31 ^ 2-1 and we add that to the current hash tally
        ]]
        String_Hash = String_Hash + string.byte(string.sub(StringToHash, i, i)) * 31^(#StringToHash - i)
    end

    return(String_Hash)

end

-- Lua implementation of BlockPos.hashCode()
local function BlockPosHash (X, Y, Z)
    -- Really easy I dont think it needs examples this is exactly how its done in minecraft
    return (Y + Z * 31) * 31 + X
end

-- Simulating an integer overflow for java compatibility limited to only overflows as the hashing functions 
-- havent generated negative numbers yet but this may need improvment in the future
-- if there is some issue around handing this function a negative number let me know 
-- as ensuring that simulated overflow or underflow for the sake of the random int function is required to garuntee an expected output
local function ConvertToUINT (number)
    -- We have a lua number which is quite large compared to java randoms use of 32 bit signed ints
    repeat
        -- If our number exceeds the bounds of a 32 bit signed int 
        if number > 2147483647 then
        -- We subtract the bound limit from out number
        number = number - 2147483648
        -- Then add the lower bound to our number functionally simulating an overflow because subtracting the upper bound leaves us with the remainder that "doesn't fit" 
        -- we can then get the lower bound and add out remainder simulating an overflow
        number = -2147483648 + number
        end
    -- Keep going until we are within range
    until (number > 0 and number < 2147483647) or (number < 0 and number * - 1 < 2147483647)
    return number
end

-- The limitations of ComputerCraft have caused this attrocious code
-- Due to the limits of ComputerCraft (Limits for only 32 bit bitwise operations)
-- and the java random function using a 48 bit integer for the seed
-- we had to get creative with making it work, so our seed is split into 5 values
local seed_high_high_high = 0
local seed_high_high = 0
local seed_high_low = 0
local seed_low_low = 0
local seed_low_high = 0

local function setSeed (n)
    -- Firstly we must handle the set seed function 
    -- This function goes as follows in the python implementation of the java random function (the code i used to create this was a python implementation of the java random)
    -- The seed used for generating is created by XORing the Seed with 0x5deece66d (Java Magic Number) and then ANDing the result with (1 << 48) - 1

    -- This defines our (1 << 48) - 1
    -- using the split chunk method as above

    -- Im almost certain that certain sections of the this big int could be removed but as soon as i got it working i don't dare touch it
    -- Should I gain the guts to edit this code in future ill attempt optimizations
    -- These values are as follows 0x[0][0000][FFFF][FFFF][FFFF] or (1 << 48) - 1
    local high_high_high_and = 0x0
    local high_high_and = 0x0
    local high_low_and = 0xFFFF
    local low_high_and = 0xFFFF
    local low_low_and = 0xFFFF

    -- The high_high_high_seed is set to zero since the user cannot actually set this with their input due to the 32 bit limit on seed entry
    seed_high_high_high = 0
    -- This effectively extracts the chunks from our input number using division as a standin for bitshifts on larger scale since we are limited with
    -- actual bitwise operations
    seed_high_high = bit32.band(math.floor(n / 0x1000000000000), 0xffff)
    seed_high_low = bit32.band(math.floor(n / 0x100000000), 0xffff)
    seed_low_high = bit32.band(math.floor(n / 0x10000), 0xffff)
    seed_low_low = bit32.band(n, 0xffff)

    -- This represents the XOR with 0x5deece66d
    seed_high_high_high = bit32.bxor(seed_high_high_high, 0x0)
    seed_high_high = bit32.bxor(seed_high_high, 0x0)
    seed_high_low = bit32.bxor(seed_high_low, 0x5)
    seed_low_high = bit32.bxor(seed_low_high, 0xdeec)
    seed_low_low = bit32.bxor(seed_low_low, 0xe66d)

    -- This is our AND with (1 << 48) - 1
    seed_high_high_high = bit32.band(seed_high_high_high, high_high_high_and)
    seed_high_high = bit32.band(seed_high_high, high_high_and)
    seed_high_low = bit32.band(seed_high_low, high_low_and)
    seed_low_high = bit32.band(seed_low_high, low_high_and)
    seed_low_low = bit32.band(seed_low_low, low_low_and)
end

local function Seed_Multiplication(Low_Low, Low_High, High_Low, High_High, High_High_High, NumberToMultiply, Special_Case)
    local tmp_low_low
    -- Firstly we multiply our chunks by the number we are working on at the moment
    if Special_Case then
        tmp_low_low = (Low_Low * NumberToMultiply + 0xb)
    else
        tmp_low_low = (Low_Low * NumberToMultiply)
    end
    local tmp_low_high = (Low_High * NumberToMultiply)
    local tmp_high_low = (High_Low * NumberToMultiply)
    local tmp_high_high = (High_High * NumberToMultiply)
    local tmp_high_high_high = (High_High_High * NumberToMultiply)

    -- Now we must do some carry calculations to ensure our chunks dont get too big
    -- We do this by cutting our getting all the digits above the 0xFFFF mark and adding them to the next chunk
    tmp_low_high = tmp_low_high + math.floor(tmp_low_low / 0x10000)
    -- Then ANDing the chunk we just worked on with 0xFFFF to remove the upper digits
    tmp_low_low = bit32.band(tmp_low_low, 0xffff)
    -- We do that with all chunks and we are left with a successful multiplication
    tmp_high_low = tmp_high_low + math.floor(tmp_low_high / 0x10000)
    tmp_low_high = bit32.band(tmp_low_high, 0xffff)

    tmp_high_high = tmp_high_high + math.floor(tmp_high_low / 0x10000)
    tmp_high_low = bit32.band(tmp_high_low, 0xffff)

    tmp_high_high_high = tmp_high_high_high + math.floor(tmp_high_high / 0x10000)
    tmp_high_high = bit32.band(tmp_high_high, 0xffff)

    return tmp_low_low, tmp_low_high, tmp_high_low, tmp_high_high, tmp_high_high_high
end

local function next(bits)
        --[[
        (Extract from the python implementation)

        "Generate the next random number.

        As in Java, the general rule is that this method returns an int that
        is `bits` bits long, where each bit is nearly equally likely to be 0
        or 1."
        ]]

        if bits < 1 then
            bits = 1
        elseif bits > 32 then
            bits = 32
        end

        -- Now we do the fun stuff namely bit int multiplacation using only what we have available in computercraft
        -- This next 140 odd lines represents about 2 days of coding this abomination of a program
        --[[
        In the python implementation this next bit is easy 
        Simply put the seed is updated to a new value
        Seed = (Seed * 0x5deece66d + 0xb) & ((1 << 48) - 1)
        With our result being
        Result = Seed >> (48 - bits)

        So lets start with the hard part Seed * 0x5deece66d + 0xb
        Youd expect that you wouldn't want to include the +0xb here but since
        its as simple as adding the 0xb to our lowest chunk i did add it here
        ]]

        --[[
        This is a code implementation of how you might do multiplication on paper
        e.g 
            123
           x046
        You start by doing
        6 * 3 = 18 so we carry the 1 and leave the 8
        then 6 * 2 + 1 from previous level = 13 so we carry the 1 and leave the 3
        and so on and so forth until we add it all at the end
        so lets start with our multiplication itself
        ]]
        -- Firstly we multiply our chunks by 0xe66d and add 0xb to our lowest chunk
        -- Special_Case is true to signify that we are also doing that addition
        local tmp_first_seed_low_low, tmp_first_seed_low_high, tmp_first_seed_high_low, tmp_first_seed_high_high, tmp_first_seed_high_high_high = Seed_Multiplication(seed_low_low, seed_low_high, seed_high_low, seed_high_high, seed_high_high_high, 0xe66d, true)
        -- Next we multiply with 0xdeec and store the results
        local tmp_second_seed_low_low, tmp_second_seed_low_high, tmp_second_seed_high_low, tmp_second_seed_high_high, tmp_second_seed_high_high_high = Seed_Multiplication(seed_low_low, seed_low_high, seed_high_low, seed_high_high, seed_high_high_high, 0xdeec, false)
        -- then finally with 0x5
        local tmp_third_seed_low_low, tmp_third_seed_low_high, tmp_third_seed_high_low, tmp_third_seed_high_high, tmp_third_seed_high_high_high = Seed_Multiplication(seed_low_low, seed_low_high, seed_high_low, seed_high_high, seed_high_high_high, 0x5, false)
        -- Now we are left with the addition of all our numbers
        -- The hardest part about this is if we dont ensure our numbers dont get too large then we cant properly do bitwise operations

        -- Im honestly not entirely sure how to explain this section but from my own understanding of this section
        -- we add the lowest chunk and the second lowest shifted up to make sure it doesnt affect the lower section
        -- This is probably to get rid of the high_high_high variable since its useless after this section
        local tmp_fourth_seed_low_low = (tmp_first_seed_low_low + bit32.lshift(tmp_first_seed_low_high, 16))
        local tmp_fourth_seed_low_high = (math.floor(tmp_fourth_seed_low_low / 0x10000) + bit32.lshift(tmp_first_seed_high_low, 16))
        tmp_fourth_seed_low_low = bit32.band(tmp_fourth_seed_low_low, 0xffff)
        local tmp_fourth_seed_high_low = (math.floor(tmp_fourth_seed_low_high / 0x10000) + bit32.lshift(tmp_first_seed_high_high, 16))
        tmp_fourth_seed_low_high = bit32.band(tmp_fourth_seed_low_high, 0xffff)
        local tmp_fourth_seed_high_high = (math.floor(tmp_fourth_seed_high_low / 0x10000) + bit32.lshift(tmp_first_seed_high_high_high, 16))
        tmp_fourth_seed_high_low = bit32.band(tmp_fourth_seed_high_low, 0xffff)

        -- Do this joining with the second set of tmp variables
        local tmp_fifth_seed_low_low = (tmp_second_seed_low_low + bit32.lshift(tmp_second_seed_low_high, 16))
        local tmp_fifth_seed_low_high = (math.floor(tmp_fifth_seed_low_low / 0x10000) + bit32.lshift(tmp_second_seed_high_low, 16))
        tmp_fifth_seed_low_low = bit32.band(tmp_fifth_seed_low_low, 0xffff)
        local tmp_fifth_seed_high_low = (math.floor(tmp_fifth_seed_low_high / 0x10000) + bit32.lshift(tmp_second_seed_high_high, 16))
        tmp_fifth_seed_low_high = bit32.band(tmp_fifth_seed_low_high, 0xffff)
        local tmp_fifth_seed_high_high = (math.floor(tmp_fifth_seed_high_low / 0x10000) + bit32.lshift(tmp_second_seed_high_high_high, 16))
        tmp_fifth_seed_high_low = bit32.band(tmp_fifth_seed_high_low, 0xffff)

        -- And the third
        local tmp_sixth_seed_low_low = (tmp_third_seed_low_low + bit32.lshift(tmp_third_seed_low_high, 16))
        local tmp_sixth_seed_low_high = (math.floor(tmp_sixth_seed_low_low / 0x10000) + bit32.lshift(tmp_third_seed_high_low, 16))
        tmp_sixth_seed_low_low = bit32.band(tmp_sixth_seed_low_low, 0xffff)
        local tmp_sixth_seed_high_low = (math.floor(tmp_sixth_seed_low_high / 0x10000) + bit32.lshift(tmp_third_seed_high_high, 16))
        tmp_sixth_seed_low_high = bit32.band(tmp_sixth_seed_low_high, 0xffff)
        local tmp_sixth_seed_high_high = (math.floor(tmp_sixth_seed_high_low / 0x10000) + bit32.lshift(tmp_third_seed_high_high_high, 16))
        tmp_sixth_seed_high_low = bit32.band(tmp_sixth_seed_high_low, 0xffff)

        -- Now we can do some more shifting to finalize the multiplacation
        -- Similare to how we shift things in multiplacation in the real world
        --[[
        
            e.g 123
               x 46
               ----
                738
              +492
              -----
             = 5658
            we do the same type of number shifting here so we keep the "digits" together so to say
        ]]
        -- Add the two sets of low digits
        local tmp_seventh_seed_low_low = tmp_fourth_seed_low_low + bit32.lshift(tmp_fourth_seed_low_high, 16)
        -- Then the middle sets of digits get added with the low digits of the second group
        local tmp_seventh_seed_low_high = tmp_fifth_seed_low_low + bit32.lshift(tmp_fourth_seed_high_low, 16) + bit32.lshift(tmp_fifth_seed_low_high, 16) + math.floor(tmp_seventh_seed_low_low / 0x10000)
        tmp_seventh_seed_low_low = bit32.band(tmp_seventh_seed_low_low, 0xffff)
        -- So on with the third
        local tmp_seventh_seed_high_low = tmp_sixth_seed_low_low + bit32.lshift(tmp_fourth_seed_high_high, 16) + bit32.lshift(tmp_fifth_seed_high_low, 16) + bit32.lshift(tmp_sixth_seed_low_high, 16) + math.floor(tmp_seventh_seed_low_high / 0x10000)
        tmp_seventh_seed_low_high = bit32.band(tmp_seventh_seed_low_high, 0xffff)
        -- Fourth and fifth
        local tmp_seventh_seed_high_high = bit32.lshift(tmp_fifth_seed_high_high, 16) + bit32.lshift(tmp_sixth_seed_high_low, 16) + math.floor(tmp_seventh_seed_high_low / 0x10000)
        tmp_seventh_seed_high_low = bit32.band(tmp_seventh_seed_high_low, 0xffff)

        local tmp_seventh_seed_high_high_high = bit32.lshift(tmp_sixth_seed_high_high, 16) + math.floor(tmp_seventh_seed_high_high / 0x10000)
        tmp_seventh_seed_high_high = bit32.band(tmp_seventh_seed_high_high, 0xffff)
        -- Im certain this explaination is subpar at best but hopefully it explains the idea

        -- set our seed variables now which is the final step of the multiplication
        seed_high_high_high, seed_high_high, seed_high_low, seed_low_high, seed_low_low = tmp_seventh_seed_high_high_high, tmp_seventh_seed_high_high, tmp_seventh_seed_high_low, tmp_seventh_seed_low_high, tmp_seventh_seed_low_low

        local high_high_high_and = 0x0
        local high_high_and = 0x0
        local high_low_and = 0xFFFF
        local low_high_and = 0xFFFF
        local low_low_and = 0xFFFF
        -- We do the ANDing with the seed
        seed_high_high_high = bit32.band(seed_high_high_high, high_high_high_and)
        seed_high_high = bit32.band(seed_high_high, high_high_and)
        seed_high_low = bit32.band(seed_high_low, high_low_and)
        seed_low_high = bit32.band(seed_low_high, low_high_and)
        seed_low_low = bit32.band(seed_low_low, low_low_and)
        -- Now we have finished the (Seed * 0x5deece66d + 0xb) & ((1 << 48) - 1)
        -- Time to generate the result
        local tmp_seed_high_high_high = seed_high_high_high
        local tmp_seed_high_high = seed_high_high
        local tmp_seed_high_low = seed_high_low
        local tmp_seed_low_high = seed_low_high
        local tmp_seed_low_low = seed_low_low
        -- Large scale bitshift
        for i = 1, (48 - bits) do
            -- We shift the bottom down by 1 bit
            tmp_seed_low_low = bit32.rshift(tmp_seed_low_low, 1)
            -- Add the bottom most bit of the next chunk to the highest bit place of the chunk we just shifted
            tmp_seed_low_low = tmp_seed_low_low + bit32.lshift(bit32.band(tmp_seed_low_high, 0x1), 15)
            -- And so on for all chunks
            tmp_seed_low_high = bit32.rshift(tmp_seed_low_high, 1)
            tmp_seed_low_high = tmp_seed_low_high + bit32.lshift(bit32.band(tmp_seed_high_low, 0x1), 15)
            tmp_seed_high_low = bit32.rshift(tmp_seed_high_low, 1)
            tmp_seed_high_low = tmp_seed_high_low + bit32.lshift(bit32.band(tmp_seed_high_high, 0x1), 15)
            tmp_seed_high_high = bit32.rshift(tmp_seed_high_high, 1)
            tmp_seed_high_high = tmp_seed_high_high + bit32.lshift(bit32.band(tmp_seed_high_high_high, 0x1), 15)
            tmp_seed_high_high_high = bit32.rshift(tmp_seed_high_high_high, 1)
            -- And we repeat however many times this function loops
        end


        local retval_low_high = tmp_seed_low_high
        local retval_low_low = tmp_seed_low_low

        low_high_and = 0x8000
        -- In the python implementation there is a section for if retval & (1 << 31)
        -- so we AND retval with (1 << 31) also known as 0x8000
        local tmp_retval_low_high = bit32.band(retval_low_high, low_high_and)
        -- (Extract from python implementation)
        -- Python and Java don't really agree on how ints work. This converts
        -- the unsigned generated int into a signed int if necessary.

        if tmp_retval_low_high then
            -- Basically if its negative we flip it
            retval_low_high = retval_low_high - 4294967296
        end
        return retval_low_high, retval_low_low
end
local function nextInt(n)

        --Return a random int in [0, `n`).

        --If `n` is not supplied, a random 32-bit integer will be returned.

        if n == nil then
            local retval_low_high, retval_low_low = next(31)
            return retval_low_low + bit32.lshift(retval_low_high, 16)
        end
        if n <= 0 then
            error("Argument must be positive!")
        end
        --[[ 
        (Extract from python implementation)
        This tricky chunk of code comes straight from the Java spec. In
        # essence, the algorithm tends to have much better entropy in the
        # higher bits of the seed, so this little bundle of joy is used to try
        # to reject values which would be obviously biased. We do have an easy
        # out for power-of-two n, in which case we can call next directly.

        # Is this a power of two?
        ]]
        -- This code isn't mine but has been adjusted to work with our cursed random function changes
        if not bit32.band(n, (n - 1)) then
            local retval_low_high, retval_low_low = next(31)
            return math.floor((n * (retval_low_low + bit32.lshift(retval_low_high, 16))) / 2147483648)
        end
        local retval_low_high, retval_low_low = next(31)
        local bits = (retval_low_low + bit32.lshift(retval_low_high, 16))
        local val = bits % n
        while (bits - val + n - 1) < 0 do
            retval_low_high, retval_low_low = next(31)
            bits = (retval_low_low + bit32.lshift(retval_low_high, 16))
            val = bits % n
            os.sleep(0.1)
        end
        return val
end



-- Code to generate a random string of digits for Just Stargate Mod 1.20.1 by implementing the Java random.nextInt function in lua
local coord_to_address = {}

function coord_to_address.Generate_Address (stargate, X, Y, Z, Dim)
    -- Info we need for the process the X, Y, Z coordinates of the base block and the dimension its located in
    local glyphs = stargate.getSymbolsMap()
    local Dim_Namespace_Hash, Dim_Hash, Dim_Whole_Hash
    local Block_Hash

    -- Firstly we split the dimension into its namespace and its resource location
    -- e.g minecraft:overworld has namespace: minecraft and resource location: overworld
    Dim_Split = ccString.split(Dim, ":")

    -- Set out Namespace and Dim variables accordingly
    Dim_Namespace, Dim = Dim_Split[1], Dim_Split[2]

    -- We must now hash these values using a lua implementation of the minecraft resource location hashing method
    -- Firstly we hash the strings with a lua implementation of java string hashing
    Dim_Namespace_Hash = StringHash(Dim_Namespace)
    Dim_Hash = StringHash(Dim)
    --[[
    Minecraft resource location hashing goes as follows 31 times the hashed namespace plus the hashed dimension name
    e.g minecraft:overworld (31 * hashed(minecraft)) + hashed(overworld)
    
    We use Convert to Int function to convert the massive lua variable to the smaller java int by simulating an overflow
    if we dont do this the seed we generate will be incorrect as java will have used a smaller number than our lua code
    ]]
    Dim_Whole_Hash = ConvertToUINT(31 * Dim_Namespace_Hash + Dim_Hash)

    -- Lua implementation of BlockPos.hashCode() from minecraft
    Block_Hash = BlockPosHash(X, Y, Z)
    -- We have to do the same Convert to int function on the blockhash for the same reasons
    -- We know that JSG (Just Stargate Mod) generates the seed for the address generation by multiplying the block hash with 31 and adding the dimension hash
    setSeed(ConvertToUINT(Block_Hash * 31) + Dim_Whole_Hash)
    -- Now the fun part, generating the actual address
    local Address = {}
    -- During our generation it is possible that we could "randomly" pick the same symbol twice
    local function InAddressAlready (symbol)
        local Present = false
        -- Iterate through the address
        for i=1, #Address do
            -- If it matches our simble then we know its already there
            if Address[i] == symbol then
                Present = true
            end
        end
        return Present
    end

    -- Generate 8 symbols for the address as this generation doesn't include the Point of Origin
    -- This code is hardcoded for the Milkyway Addressing system but some small adjustments can be made to change that
    for i = 1, 8 do
        -- We set out seed earlier but now we must generate the first number
        local next_Glyph = nextInt(38)
        -- If that random number is 4 we discard it and generate new symbols until we dont get 4 as 4 is the point of origin
        if next_Glyph == 4 then
            repeat
                next_Glyph = nextInt(38)
                os.sleep(0.1)
            until next_Glyph ~= 4
        end
        -- Checking if its already generated a symbol before does the same as above, regenerate until a new symbol is picked
        if InAddressAlready (glyphs[next_Glyph + 1]) then
            repeat
                next_Glyph = nextInt(38)
                os.sleep(0.1)
            until InAddressAlready (glyphs[next_Glyph + 1]) == false
        end
        -- We have generated a symbol and we know its safe to add to the address
        Address[i] = glyphs[next_Glyph + 1]
    end
    -- We are done the whole address is generated
    return (Address)
end


return coord_to_address




