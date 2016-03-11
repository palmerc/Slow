import UIKit
import Metal



class ViewController: UIViewController
{
    private var numberOfValues = 130000
    private var numberOfChannels = 128

    private var metalDevice: MTLDevice!
    private var metalDefaultLibrary: MTLLibrary!
    private var metalCommandQueue: MTLCommandQueue!

    private var metalKernelFunction: MTLFunction!
    private var metalPipelineState: MTLComputePipelineState!

    private var metalBuffer1: MTLBuffer!
    private var metalBuffer2: MTLBuffer!

    override func viewDidLoad() {
        super.viewDidLoad()

        setup()
        compute()
    }

    func setup()
    {
        let (metalDevice, metalLibrary, metalCommandQueue) = self.setupMetalDevice()
        if let metalDevice = metalDevice, metalLibrary = metalLibrary, metalCommandQueue = metalCommandQueue {
            let (metalChannelDataKernelFunction, metalChannelDataPipelineState) = self.setupShaderInMetalPipelineWithName("writeSomeZeros", withDevice: metalDevice, inLibrary: metalLibrary)
            self.metalKernelFunction = metalChannelDataKernelFunction
            self.metalPipelineState = metalChannelDataPipelineState

            let byteCount1 = self.numberOfChannels * self.numberOfValues * sizeof(Float)
            self.metalBuffer1 = metalDevice.newBufferWithLength(byteCount1, options: .StorageModeShared)

            let byteCount2 = self.numberOfValues * sizeof(UInt8)
            self.metalBuffer2 = metalDevice.newBufferWithLength(byteCount2, options: .StorageModeShared)

            self.metalDevice = metalDevice
            self.metalDefaultLibrary = metalLibrary
            self.metalCommandQueue = metalCommandQueue
        } else {
            print("Failed to find a Metal device.")
            exit(1)
        }
    }

    func compute()
    {
        let time = executionTimeInterval { () -> () in
            let contents = self.metalBuffer1.contents()
            let opaque = COpaquePointer(contents)
            let pointer = UnsafeMutablePointer<Float>(opaque)
            let buffer = UnsafeMutableBufferPointer<Float>(start: pointer, count: self.numberOfChannels * self.numberOfValues)
            for index in buffer.startIndex ..< buffer.endIndex {
                buffer[index] = 1.0
            }
            
            let metalCommandBuffer = self.metalCommandQueue.commandBuffer()
            let commandEncoder = metalCommandBuffer.computeCommandEncoder()

            if let pipelineState = self.metalPipelineState {
                commandEncoder.setComputePipelineState(pipelineState)

                commandEncoder.setBuffer(self.metalBuffer1, offset: 0, atIndex: 0)
                commandEncoder.setBuffer(self.metalBuffer2, offset: 0, atIndex: 1)

                let threadExecutionWidth = pipelineState.threadExecutionWidth
                let threadsPerThreadgroup = MTLSize(width: threadExecutionWidth, height: 1, depth: 1)
                let threadGroups = MTLSize(width: self.numberOfValues / threadsPerThreadgroup.width, height: 1, depth:1)

                commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerThreadgroup)
                commandEncoder.endEncoding()
                metalCommandBuffer.commit()
                metalCommandBuffer.waitUntilCompleted()
            }
        }

        var output = [UInt8](count: self.numberOfValues, repeatedValue: 0)
        let data = NSData(bytesNoCopy: self.metalBuffer2.contents(), length: self.numberOfValues, freeWhenDone: false)
        data.getBytes(&output, length: self.numberOfValues)

        print("\(output)")
        print("\(time)")
    }

    private func setupMetalDevice() -> (metalDevice: MTLDevice?,
        metalLibrary: MTLLibrary?,
        metalCommandQueue: MTLCommandQueue?)
    {
        let metalDevice: MTLDevice? = MTLCreateSystemDefaultDevice()
        let metalLibrary = metalDevice?.newDefaultLibrary()
        let metalCommandQueue = metalDevice?.newCommandQueue()

        return (metalDevice, metalLibrary, metalCommandQueue)
    }

    private func setupShaderInMetalPipelineWithName(kernelFunctionName: String, withDevice metalDevice: MTLDevice?, inLibrary metalLibrary: MTLLibrary?) ->
        (metalKernelFunction: MTLFunction?,
        metalPipelineState: MTLComputePipelineState?)
    {
        let metalKernelFunction: MTLFunction? = metalLibrary?.newFunctionWithName(kernelFunctionName)

        let computePipeLineDescriptor = MTLComputePipelineDescriptor()
        computePipeLineDescriptor.computeFunction = metalKernelFunction

        var metalPipelineState: MTLComputePipelineState? = nil
        do {
            metalPipelineState = try metalDevice?.newComputePipelineStateWithFunction(metalKernelFunction!)
        } catch let error as NSError {
            print("Compute pipeline state acquisition failed. \(error.localizedDescription)")
        }

        return (metalKernelFunction, metalPipelineState)
    }

    func executionTimeInterval(block: () -> ()) -> CFTimeInterval
    {
        let start = CACurrentMediaTime()
        block();
        let end = CACurrentMediaTime()
        return end - start
    }

}

