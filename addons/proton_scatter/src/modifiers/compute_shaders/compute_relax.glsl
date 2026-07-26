#[compute]
#version 450


layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) readonly buffer BufferIn
{
    vec4 data[];
} buffer_in;

layout(set = 0, binding = 1, std430) restrict buffer BufferOut
{
    vec4 data[];
} buffer_out;

void main()
{
    int last_element_index = int(uint(buffer_in.data.length()));
    uint workgroupSize = 64u;
    uint index = (gl_WorkGroupID.x * workgroupSize) + gl_LocalInvocationIndex;
    vec3 infvec = vec3(999999.0);
    vec3 closest = infvec;
    vec3 origin = buffer_in.data[index].xyz;
    for (int i = 0; i <= last_element_index; i++)
    {
        vec3 newvec = buffer_in.data[i].xyz;
        if (uint(i) == index)
        {
            continue;
        }
        float olddist = length(closest - origin);
        float newdist = length(newvec - origin);
        if (newdist < olddist)
        {
            closest = newvec;
        }
    }
    buffer_out.data[index] = vec4(origin - closest, 0.0);
}


