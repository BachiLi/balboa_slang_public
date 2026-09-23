import slangpy as spy

class ComputeShader:
    def __init__(self, module, kernel):
        self.module = module
        self.kernel = kernel

def load_compute_shader(slang_device, filename, entry_name='compute_main') -> ComputeShader:
    module = slang_device.load_module(filename)
    entry = module.entry_point(entry_name)
    program = slang_device.link_program([module], [entry])
    kernel = slang_device.create_compute_kernel(program)
    py_module = spy.Module.load_from_module(slang_device, module)
    return ComputeShader(py_module, kernel)
