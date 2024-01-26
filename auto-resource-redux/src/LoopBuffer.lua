local LoopBuffer = {}

function LoopBuffer.new()
  return {
    iter_index = 0,
    size = 0,
    data = {}
  }
end

function LoopBuffer.add(buffer, value)
  buffer.size = buffer.size + 1
  buffer.data[buffer.size] = value
end

function LoopBuffer.remove_current(buffer)
  assert(buffer.size > 0 and buffer.iter_index > 0)
  -- replace entry with the last one and then shrink the buffer
  buffer.data[buffer.iter_index] = buffer.data[buffer.size]
  buffer.data[buffer.size] = nil
  buffer.size = buffer.size - 1
  buffer.iter_index = buffer.iter_index - 1
end

function LoopBuffer.next(buffer)
  if buffer.size <= 0 then
    return nil
  end
  buffer.iter_index = buffer.iter_index % buffer.size + 1
  return buffer.data[buffer.iter_index]
end

return LoopBuffer