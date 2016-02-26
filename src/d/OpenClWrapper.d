module OpenClWrapper;

import std.file : readText;
import std.string; // for toStringz

// for debugging
import std.stdio : writeln;

import memory.MemoryBlock : MemoryBlock;
import opencl.Cl;
import opencl.ClGl;
import gl;
import Glx;
import IDisposable : IDisposable;
import ErrorStack : ErrorStack;

// TODO< build in new ResourceDag for managment of the handles for OpenCL >

// this is a "simple" OpenCL warper
// is used to improve readability of the openCL things
class OpenClWrapper : IDisposable {
   public static class Kernel : IDisposable {
		public this(cl_kernel handle) {
			this.handle = handle;
		}

		public final cl_kernel getHandle() {
			return handle;
		}

		public void dispose() {
			clReleaseKernel(handle);
			handle = 0;
		}

		protected cl_kernel handle;
	};
	
	// this is a Capsulation for the OpenCL program and the possible actions of it
	public static class Program : IDisposable {
	   	// creates a Kernel from the openCL Program Object
		public final Kernel createKernel(string name) {
			return null; // TODO
		}

		public void dispose() {
			clReleaseProgram(program);
			program = 0;
		}
		
		protected cl_program program;
	};

	
	// this is visible from outside
	// this is a list with events for that a comand can wait before it is run in the queue
	// the user have to make shure that he deletes it later
	// TODO< do bind the Objekct to the OpenClWrapper object
	public static class EventList {
		//protected vector<cl_event> events; TODO
	};
	

	// this is a Capsulation for a Buffer and the possible actions for it
	public class Buffer {
		// is a clas for error-throwing
		//class ExceptionMappingFailed {};
		this();
		~this();
		
		// this write to the buffer
		// if Waitlist is not nullptr, it allocates a new event in the Eventlist and pass the pointer to it to the API
		// throws a error if something goes wrong
		public final void write(cl_bool Blocking, const void *Ptr, size_t Size, size_t Offset, cl_event* Event = null, EventList* Waitlist = null);
		
		// this writes to the buffer and passes the "native" waitlist as a pointer with the count to the OpenCL-API
		public final void write(cl_bool Blocking, const void *Ptr, size_t Size, size_t Offset, cl_event* Event = null, cl_uint WaitlistCount = 0, cl_event* Waitlist = null);

		// this reads from a buffer
		// if Eventlist is not nullptr, it allocates a new event in the Eventlist and pass the pointer to it to the API
		// throws a error if something goes wrong
		public final void read(cl_bool Blocking, void* Ptr, size_t Size, size_t Offset, cl_event* Event = null, EventList* Eventlist = null);
		
		// this reads from a buffer
		// this reads from the buffer and passes the "native" waitlist as a pointer with the count to the OpenCL-API
		// throws a error if something goes wrong
		public final void read(cl_bool Blocking, void *Ptr, size_t Size, size_t Offset, cl_event* Event = null, cl_uint WaitlistCount = 0, cl_event* Waitlist = null);
		

		// map a buffer and return the memory to it 
		// TODO< event things and so on >
		public final void* map(cl_bool Blocking, cl_map_flags Flags, size_t Size, size_t Offset);
		

		// this returns the pointer to the buffer openCL object
		// TODO< maybe we don't need this kind of function cos it should not be public accessable >
		public final cl_mem* getPtr() {
			return &buffer;
		}

		protected cl_mem buffer;
	};

	public class Image : IDisposable {
	   public:
		// TODO< maybe we don't need this kind of function cos it should not be public accessable >
		public final cl_mem getHandle() {
			return image;
		}

		public void dispose() {
			clReleaseMemObject(image);
		}

		protected cl_mem image;
	};

	public final void aquire(ErrorStack LocalErrorstack) {
		cl_int ret;
		cl_uint numberOfPlatforms;

		// query the count of the available platforms
		ret = clGetPlatformIDs(0, null, &numberOfPlatforms);
		if( ret != CL_SUCCESS ) {
			string ErrorText = getErrorText(ret);
			LocalErrorstack.setRecoverableError("Couldn't query the number of available Platforms!", [ErrorText], __FILE__, __LINE__);
			return;
		}

		if( numberOfPlatforms == 0 ) {
			LocalErrorstack.setRecoverableError("There are no Platforms!", [], __FILE__, __LINE__);
			return;
		}

		// allocate an memory region where the Platform id's can be saved
		cl_platform_id[] platformIds = new cl_platform_id[numberOfPlatforms];
		
		// get all available platform ids
		ret = clGetPlatformIDs(numberOfPlatforms, platformIds.ptr, null);
		if( ret != CL_SUCCESS ) {
			string ErrorText = getErrorText(ret);
			LocalErrorstack.setRecoverableError("Couldn't query the available Platforms!", [ErrorText], __FILE__, __LINE__);
			return;
		}

		/*
			this can be anytime helpful
		size_t size;
		char* stringInfo;
		// enumerate the informations about the device
		// TODO< enumerate the informations of multiple platforms if we have many and choose the right one >
		cl_platform_id id = platformIds[0];
		ret = clGetPlatformInfo(platformIds[0], CL_PLATFORM_EXTENSIONS , 0, NULL, &size); 
		if( ret != CL_SUCCESS ) {
			throw ErrorMessage("Couldn't get informations about the Platform!"); 
		}
		
		stringInfo = new char[size];
		if( !stringInfo ) {
			throw ErrorMessage("Couldn't allocate array!");
		}
		ret = clGetPlatformInfo(platformIds[0], CL_PLATFORM_EXTENSIONS , size, stringInfo, NULL);
		if( ret != CL_SUCCESS ) {
			throw ErrorMessage("Couldn't get informations about the Platform!"); 
		}
		
		delete stringInfo;
		*/

		// fill the properties structure
		cl_context_properties[] Properties = new cl_context_properties[3*2 + 1];

		Properties[0*2 + 0] = cast(cl_context_properties)CL_CONTEXT_PLATFORM;
		Properties[0*2 + 1] = cast(cl_context_properties)platformIds[0];

			// windows : CL_GL_CONTEXT_KHR, (cl_context_properties)wglGetCurrentContext()
			//CL_WGL_HDC_KHR, (cl_context_properties)wglGetCurrentDC(), required for windows?

		Properties[1*2 + 0] = cast(cl_context_properties)CL_GL_CONTEXT_KHR;
		Properties[1*2 + 1] = cast(cl_context_properties)glXGetCurrentContext();
		Properties[2*2 + 0] = cast(cl_context_properties)CL_GLX_DISPLAY_KHR;
		Properties[2*2 + 1] = cast(cl_context_properties)glXGetCurrentDisplay();
			
		Properties[3*2 + 0] = null;


		// Create a context to run OpenCL
		GPUContext = clCreateContextFromType(Properties.ptr, CL_DEVICE_TYPE_GPU, null, null, &ret); 
		if( ret != CL_SUCCESS ) {
			string ErrorText = getErrorText(ret);
			LocalErrorstack.setRecoverableError("Could not create the GPU-Context!", [ErrorText], __FILE__, __LINE__);
			return;
		}

		// Get the list of GPU devices associated with this context 
		size_t ParmDataBytes; 

		ret = clGetContextInfo(GPUContext, CL_CONTEXT_DEVICES, 0, null, &ParmDataBytes); 
		if( ret != CL_SUCCESS ) {
			string ErrorText = getErrorText(ret);
			LocalErrorstack.setRecoverableError("Can't get the context informations!", [ErrorText], __FILE__, __LINE__);
			return;
		}
		
		GPUDevices = new cl_device_id[ParmDataBytes/cl_device_id.sizeof];

		ret = clGetContextInfo(GPUContext, CL_CONTEXT_DEVICES, ParmDataBytes, GPUDevices.ptr, null); 
		if( ret != CL_SUCCESS ) {
			string ErrorText = getErrorText(ret);
			LocalErrorstack.setRecoverableError("Can't get the context informations!", [ErrorText], __FILE__, __LINE__);
			return;
		}

		// TODO< device selection >
		
		// Create a command-queue on the first GPU device 
		GPUCommandQueue = clCreateCommandQueue(GPUContext,
		                                       GPUDevices[0],
		                                       //CL_QUEUE_OUT_OF_ORDER_EXEC_MODE_ENABLE |/* we want it for more speed */     no we don't until we wait for the kernel execution
		                                       CL_QUEUE_PROFILING_ENABLE ,              /* we want to profile the timings */
		                                       null);

		if( !GPUCommandQueue ) {
			LocalErrorstack.setRecoverableError("Couldn't create the Command Queue!", [], __FILE__, __LINE__);
			return;
		}
	}
	
	// this try to compile the Programm Filename and return on success a program Object
	// the program object is managed by this Class
	public final Program openAndCompile(string Filename, ErrorStack LocalErrorstack) {
		cl_int ret;

		string ProgramContent = readText(Filename);

		Program CreatedProgram = new Program();

		immutable(char)*[] SourcePointers = new immutable(char)*[1];
		SourcePointers[0] = toStringz(ProgramContent);

		CreatedProgram.program = clCreateProgramWithSource(GPUContext, 1, SourcePointers.ptr, null, null); 
		if( !CreatedProgram.program ) {
			LocalErrorstack.setRecoverableError("Can't compile the Source!", [Filename], __FILE__, __LINE__);
			return null;
		}

		// Build the program (OpenCL JIT compilation) 
		ret = clBuildProgram(CreatedProgram.program, 0, null, null, null, null); 
		if( ret != CL_SUCCESS ) {
			// TODO< device selection >

			size_t AllocationSize;
			cl_int Ret2;
			Ret2 = clGetProgramBuildInfo(CreatedProgram.program, GPUDevices[0], CL_PROGRAM_BUILD_LOG, 0, null, &AllocationSize);
			if( ret != CL_SUCCESS ) {
				LocalErrorstack.setRecoverableError("Can't build the program!", [Filename], __FILE__, __LINE__);
			}

			MemoryBlock LogCString;
			LogCString.configure(ubyte.sizeof);
			bool CalleeSuccess;
			LogCString.expandNeeded(AllocationSize, CalleeSuccess);
			if( !CalleeSuccess ) {
				LocalErrorstack.setFatalError("Out of Memory!", [], __FILE__, __LINE__);
			}
			scope(exit) LogCString.free();

			// we get the compilation error
			Ret2 = clGetProgramBuildInfo(CreatedProgram.program, GPUDevices[0], CL_PROGRAM_BUILD_LOG, AllocationSize, LogCString.unsafeGetPtr(), null);
			if( ret != CL_SUCCESS ) {
				LocalErrorstack.setRecoverableError("Can't build the program!", [Filename], __FILE__, __LINE__);
			}
			
			// TODO< output error >
			string CompileLogDString = cast(string)((cast(char*)LogCString.unsafeGetPtr())[0 .. AllocationSize]);
			LocalErrorstack.setRecoverableError("Can't build the program!", [Filename, CompileLogDString], __FILE__, __LINE__);
			return null;
		}

		return CreatedProgram;
	}

	// this creates a buffer object and return a buffer object
	// throw a error if something goes wrong
	Buffer createBuffer(cl_mem_flags Flags, size_t Size, void* Ptr) {
		return null; // TODO
	}

	// this creates a "OpenCL image object" from a openGL Texture
	// Flags: see OpenCL clCreateFromGLTexture2D function documentation
	// Texture: is the existing openGL texture ID
	
	// Throws an Error if something goes wrong

	// openCL/openGL note:
	//  texture_target is everytime GL_TEXTURE_2D
	//  miplevel is everytime 0
	Image createImageFromOpenGLTexture(cl_mem_flags Flags, GLuint Texture, ErrorStack LocalErrorstack) {
		cl_mem ret;
		cl_int errorcode;

		// TODO< check for OpenCL 1.1 or higher to not use this >
		
		ret = clCreateFromGLTexture2D(GPUContext, Flags, GL_TEXTURE_2D, 0, Texture, &errorcode);

		if( errorcode != CL_SUCCESS ) {
			string ErrorText = getErrorText(errorcode);
			LocalErrorstack.setRecoverableError("Can't create the OpenCL Texture from the OpenGL Texture!", [ErrorText], __FILE__, __LINE__);
			return null;
		}

		Image CreatedImage = new Image();
		CreatedImage.image = ret;
		return CreatedImage;
	}

	Image createImage2dOnDevice(cl_mem_flags flags, uint sizeX, uint sizeY, cl_channel_order channelOrder, cl_channel_type channelType, ErrorStack LocalErrorstack) {
		cl_mem ret;
		cl_int errorcode;

		cl_image_format openclImageFormat;
		openclImageFormat.image_channel_order = channelOrder;
		openclImageFormat.image_channel_data_type = channelType;

		// TODO< check for OpenCL 1.1 or higher to not use this >

		ret = clCreateImage2D(
			GPUContext,
	  		flags,
	  		&openclImageFormat,
	  		sizeX,
	  		sizeY,
	  		0,
	  		null,
	  		&errorcode
	  	);

		if( errorcode != CL_SUCCESS ) {
			string ErrorText = getErrorText(ret);
			LocalErrorstack.setRecoverableError("Can't create a 2d Image!", [ErrorText], __FILE__, __LINE__);
		}

		// create a new Image Object
		OpenClWrapper.Image newImage = new OpenClWrapper.Image();
		newImage.image = ret;
		return newImage;
	}

	// this is for testcode
	// TODO< remove it >
	// TESTCODE
	// returns the command queue
	cl_command_queue testcode_getCQ() {
		return GPUCommandQueue;
	}

	// this is a little helper function that converts the errorcode into its text
	public static string getErrorText(cl_int Errorcode) {
		// from http://stackoverflow.com/questions/24326432/convenient-way-to-show-opencl-error-codes
		switch(Errorcode){
		    // run-time and JIT compiler errors
		    case 0: return "CL_SUCCESS";
		    case -1: return "CL_DEVICE_NOT_FOUND";
		    case -2: return "CL_DEVICE_NOT_AVAILABLE";
		    case -3: return "CL_COMPILER_NOT_AVAILABLE";
		    case -4: return "CL_MEM_OBJECT_ALLOCATION_FAILURE";
		    case -5: return "CL_OUT_OF_RESOURCES";
		    case -6: return "CL_OUT_OF_HOST_MEMORY";
		    case -7: return "CL_PROFILING_INFO_NOT_AVAILABLE";
		    case -8: return "CL_MEM_COPY_OVERLAP";
		    case -9: return "CL_IMAGE_FORMAT_MISMATCH";
		    case -10: return "CL_IMAGE_FORMAT_NOT_SUPPORTED";
		    case -11: return "CL_BUILD_PROGRAM_FAILURE";
		    case -12: return "CL_MAP_FAILURE";
		    case -13: return "CL_MISALIGNED_SUB_BUFFER_OFFSET";
		    case -14: return "CL_EXEC_STATUS_ERROR_FOR_EVENTS_IN_WAIT_LIST";
		    case -15: return "CL_COMPILE_PROGRAM_FAILURE";
		    case -16: return "CL_LINKER_NOT_AVAILABLE";
		    case -17: return "CL_LINK_PROGRAM_FAILURE";
		    case -18: return "CL_DEVICE_PARTITION_FAILED";
		    case -19: return "CL_KERNEL_ARG_INFO_NOT_AVAILABLE";

		    // compile-time errors
		    case -30: return "CL_INVALID_VALUE";
		    case -31: return "CL_INVALID_DEVICE_TYPE";
		    case -32: return "CL_INVALID_PLATFORM";
		    case -33: return "CL_INVALID_DEVICE";
		    case -34: return "CL_INVALID_CONTEXT";
		    case -35: return "CL_INVALID_QUEUE_PROPERTIES";
		    case -36: return "CL_INVALID_COMMAND_QUEUE";
		    case -37: return "CL_INVALID_HOST_PTR";
		    case -38: return "CL_INVALID_MEM_OBJECT";
		    case -39: return "CL_INVALID_IMAGE_FORMAT_DESCRIPTOR";
		    case -40: return "CL_INVALID_IMAGE_SIZE";
		    case -41: return "CL_INVALID_SAMPLER";
		    case -42: return "CL_INVALID_BINARY";
		    case -43: return "CL_INVALID_BUILD_OPTIONS";
		    case -44: return "CL_INVALID_PROGRAM";
		    case -45: return "CL_INVALID_PROGRAM_EXECUTABLE";
		    case -46: return "CL_INVALID_KERNEL_NAME";
		    case -47: return "CL_INVALID_KERNEL_DEFINITION";
		    case -48: return "CL_INVALID_KERNEL";
		    case -49: return "CL_INVALID_ARG_INDEX";
		    case -50: return "CL_INVALID_ARG_VALUE";
		    case -51: return "CL_INVALID_ARG_SIZE";
		    case -52: return "CL_INVALID_KERNEL_ARGS";
		    case -53: return "CL_INVALID_WORK_DIMENSION";
		    case -54: return "CL_INVALID_WORK_GROUP_SIZE";
		    case -55: return "CL_INVALID_WORK_ITEM_SIZE";
		    case -56: return "CL_INVALID_GLOBAL_OFFSET";
		    case -57: return "CL_INVALID_EVENT_WAIT_LIST";
		    case -58: return "CL_INVALID_EVENT";
		    case -59: return "CL_INVALID_OPERATION";
		    case -60: return "CL_INVALID_GL_OBJECT";
		    case -61: return "CL_INVALID_BUFFER_SIZE";
		    case -62: return "CL_INVALID_MIP_LEVEL";
		    case -63: return "CL_INVALID_GLOBAL_WORK_SIZE";
		    case -64: return "CL_INVALID_PROPERTY";
		    case -65: return "CL_INVALID_IMAGE_DESCRIPTOR";
		    case -66: return "CL_INVALID_COMPILER_OPTIONS";
		    case -67: return "CL_INVALID_LINKER_OPTIONS";
		    case -68: return "CL_INVALID_DEVICE_PARTITION_COUNT";

		    // extension errors
		    case -1000: return "CL_INVALID_GL_SHAREGROUP_REFERENCE_KHR";
		    case -1001: return "CL_PLATFORM_NOT_FOUND_KHR";
		    case -1002: return "CL_INVALID_D3D10_DEVICE_KHR";
		    case -1003: return "CL_INVALID_D3D10_RESOURCE_KHR";
		    case -1004: return "CL_D3D10_RESOURCE_ALREADY_ACQUIRED_KHR";
		    case -1005: return "CL_D3D10_RESOURCE_NOT_ACQUIRED_KHR";
		    default: return "Unknown OpenCL error";
	    }
	}

	public void dispose() {
		if( GPUContext != 0 ) {
			clReleaseContext(GPUContext);
			GPUContext = 0;
		}
		
		if( GPUCommandQueue != 0 ) {
			clReleaseCommandQueue(GPUCommandQueue);
			GPUCommandQueue = 0;
		}
	}

	protected cl_context GPUContext;
	protected cl_command_queue GPUCommandQueue;
	protected cl_device_id[] GPUDevices;
};





/*


std::shared_ptr<OpenClWrapper::Kernel> OpenClWrapper::Program::createKernel(string name) {
	cl_kernel handle;
	
	handle = clCreateKernel(program, name.c_str(), nullptr); 
	if( !handle ) {
		throw ErrorMessage("Can't create the Kernel!");
	}

	return std::shared_ptr<OpenClWrapper::Kernel>(new OpenClWrapper::Kernel(handle));
}

OpenClWrapper::Kernel::Kernel(cl_kernel handle) {
	this->handle = handle;
}


cl_kernel OpenClWrapper::Kernel::getHandle() const {
	return handle;
}


OpenClWrapper::Buffer* OpenClWrapper::createBuffer(cl_mem_flags Flags, size_t Size, void *Ptr) {
	Buffer* buffer;
	
	buffer = new Buffer(this);
	if( !buffer ) {
		throw NoMemory();
	}

	buffer->buffer = clCreateBuffer(GPUContext, Flags, Size, Ptr, nullptr);
	if( !buffer->buffer ) {
		throw ErrorMessage("Can't create the Buffer!");
	}
	
	return buffer;
}

OpenClWrapper::Buffer::Buffer(OpenClWrapper* OpenClWrapperPtr) {
	openclw = OpenClWrapperPtr;
}

OpenClWrapper::Buffer::~Buffer() {
	clReleaseMemObject(buffer);
}


void OpenClWrapper::Buffer::write(cl_bool Blocking, const void *Ptr, size_t Size, size_t Offset, cl_event* Event, OpenClWrapper::EventList* Waitlist) {
	cl_int ret;

	if( Waitlist == nullptr ) {
		ret = clEnqueueWriteBuffer(openclw->GPUCommandQueue, buffer, Blocking, Offset, Size, Ptr, 0, 0, Event);
	}
	else {
		ret = clEnqueueWriteBuffer(openclw->GPUCommandQueue, buffer, Blocking, Offset, Size, Ptr, Waitlist->events.size(), &(Waitlist->events[0]), Event);
	}

	if( ret != CL_SUCCESS ) {
		throw ErrorMessage("Can't write to OpenCL Buffer");
	}
}

void OpenClWrapper::Buffer::write(cl_bool Blocking, const void *Ptr, size_t Size, size_t Offset, cl_event* Event, cl_uint WaitlistCount, cl_event* Waitlist) {
	cl_int ret;

	ret = clEnqueueWriteBuffer(openclw->GPUCommandQueue, buffer, Blocking, Offset, Size, Ptr, WaitlistCount, Waitlist, Event);
	
	if( ret != CL_SUCCESS ) {
		throw ErrorMessage("Can't write to OpenCL Buffer");
	}
}

void OpenClWrapper::Buffer::read(cl_bool Blocking, void *Ptr, size_t Size, size_t Offset, cl_event* Event, OpenClWrapper::EventList* Eventlist) {
	cl_int ret;

	if( Eventlist == nullptr ) {
		ret = clEnqueueReadBuffer(openclw->GPUCommandQueue, buffer, Blocking, Offset, Size, Ptr, 0, 0, Event);
	}
	else {
		ret = clEnqueueReadBuffer(openclw->GPUCommandQueue, buffer, Blocking, Offset, Size, Ptr, Eventlist->events.size(), &(Eventlist->events[0]), Event);
	}

	if( ret != CL_SUCCESS ) {
		throw ErrorMessage("Can't read from OpenCL Buffer");
	}
}

void OpenClWrapper::Buffer::read(cl_bool Blocking, void *Ptr, size_t Size, size_t Offset, cl_event* Event, cl_uint WaitlistCount, cl_event* Waitlist) {
	cl_int ret;

	ret = clEnqueueReadBuffer(openclw->GPUCommandQueue, buffer, Blocking, Offset, Size, Ptr, WaitlistCount, Waitlist, Event);
	
	if( ret != CL_SUCCESS ) {
		throw ErrorMessage("Can't read from OpenCL Buffer");
	}
}

void* OpenClWrapper::Buffer::map(cl_bool Blocking, cl_map_flags Flags, size_t Size, size_t Offset) {
	void* ret = clEnqueueMapBuffer(openclw->GPUCommandQueue, buffer, Blocking, Flags, Offset, Size, 0, 0, 0, 0);
	if( !ret ) {
		throw ExceptionMappingFailed();
	}

	return ret;
}
*/