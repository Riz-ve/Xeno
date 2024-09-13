#pragma once

#include <Windows.h>
#include <vector>
#include <string>
#include <thread>
#include <mutex>
#include <unordered_set>

#include <iostream>
#include <filesystem>

#include "Luau/Compiler.h"
#include "Luau/BytecodeBuilder.h"
#include "Luau/BytecodeUtils.h"

#include "utils/ntdll.h"

namespace offsets {
    // Instance
    constexpr std::uintptr_t This = 0x8;
    constexpr std::uintptr_t Name = 0x48;
    constexpr std::uintptr_t Children = 0x50;
    constexpr std::uintptr_t Parent = 0x60;

    constexpr std::uintptr_t ClassDescriptor = 0x18;
    constexpr std::uintptr_t ClassName = 0x8;

    // Scripts
    constexpr std::uintptr_t ModuleScriptEmbedded = 0x160;
    constexpr std::uintptr_t IsCoreScript = 0x1a8;
    constexpr std::uintptr_t ModuleFlags = IsCoreScript - 0x4;
    constexpr std::uintptr_t LocalScriptEmbedded = 0x1c0;

    constexpr std::uintptr_t Bytecode = 0x10;
    constexpr std::uintptr_t BytecodeSize = 0x20;

    // Other
    constexpr std::uintptr_t LocalPlayer = 0x100;
    constexpr std::uintptr_t ObjectValue = 0xc8;
}

const std::string_view Xeno_Version = "1.0.4";

template<typename T>
T read_memory(std::uintptr_t address, HANDLE handle);

template <typename T>
bool write_memory(std::uintptr_t address, const T& value, HANDLE handle);

extern std::mutex clientsMtx;

namespace functions { // functions for rbx
    std::vector<std::uintptr_t> GetChildrenAddresses(std::uintptr_t address, HANDLE handle);
    std::string ReadRobloxString(std::uintptr_t address, HANDLE handle);
}

/*
struct ClassDescriptor {
    const std::uintptr_t Self;
    const std::string Name; // ClassName
    const std::uint64_t Capabilities;

    ClassDescriptor(std::uintptr_t& address, HANDLE& handle) :
        Self(read_memory<std::uintptr_t>(address + offsets::ClassDescriptor, handle)),
        Name(functions::ReadRobloxString(read_memory<std::uintptr_t>(Self + offsets::ClassName, handle), handle)),
        Capabilities(read_memory<std::uint64_t>(Self + 0x370, handle))
    {}
};
*/

class Instance {
private:
    const std::uintptr_t _Self;
    HANDLE handle;
public:
    Instance(std::uintptr_t address, HANDLE handle) :
        handle(handle),
        _Self(address)
    {}

    // Instance functions
    std::vector<std::uintptr_t> GetChildrenAddresses() const {
        return functions::GetChildrenAddresses(_Self, handle);
    }

    std::vector<std::unique_ptr<Instance>> GetChildren() const {
        std::vector<std::uintptr_t> childAddresses = GetChildrenAddresses();
        std::vector<std::unique_ptr<Instance>> children;
        for (std::uintptr_t address : childAddresses) {
            children.push_back(std::make_unique<Instance>(address, handle));
        }
        return children;
    }

    std::uintptr_t FindFirstChildAddress(const std::string_view name) const {
        std::vector<std::uintptr_t> childAddresses = GetChildrenAddresses();
        for (std::uintptr_t address : childAddresses) {
            if (functions::ReadRobloxString(read_memory<std::uintptr_t>(address + offsets::Name, handle), handle) == name)
                return address;
        }
        return 0;
    }

    std::unique_ptr<Instance> FindFirstChild(const std::string_view name) const {
        std::uintptr_t childAddress = FindFirstChildAddress(name);
        if (childAddress != 0)
            return std::make_unique<Instance>(childAddress, handle);
        return nullptr;
    }

    std::uintptr_t WaitForChildAddress(const std::string_view name, int timeout = 9e9) const {
        std::uintptr_t existing = FindFirstChildAddress(name);
        if (existing != 0)
            return existing;

        std::chrono::steady_clock::time_point start_time = std::chrono::high_resolution_clock::now();
        while (std::chrono::high_resolution_clock::now() - start_time <= std::chrono::seconds(timeout)) {
            if (FindFirstChildAddress(name))
                return FindFirstChildAddress(name);
            Sleep(100);
        }
        return 0;
    }

    std::unique_ptr<Instance> WaitForChild(const std::string_view name, int timeout = 9e9) const {
        std::uintptr_t childAddress = WaitForChildAddress(name, timeout);
        if (childAddress != 0)
            return std::make_unique<Instance>(childAddress, handle);
        return nullptr;
    }

    std::uintptr_t FindFirstChildOfClassAddress(const std::string_view className) const {
        std::vector<std::uintptr_t> childAddresses = GetChildrenAddresses();
        for (std::uintptr_t address : childAddresses) {
            if (functions::ReadRobloxString(read_memory<std::uintptr_t>(read_memory<std::uintptr_t>(address + offsets::ClassDescriptor, handle) + offsets::ClassName, handle), handle) == className)
                return address;
        }
        return 0;
    }

    std::unique_ptr<Instance> FindFirstChildOfClass(const std::string_view className) const {
        std::uintptr_t childAddress = FindFirstChildOfClassAddress(className);
        if (childAddress != 0)
            return std::make_unique<Instance>(childAddress, handle);
        return nullptr;
    }

    // Miscellaneous
    bool SetBytecode(const std::string& compressedBytecode, bool revertBytecode = false) const {
        if (ClassName() != "LocalScript" && ClassName() != "ModuleScript")
            return false;

        std::uintptr_t embeddedSourceOffset = (ClassName() == "LocalScript") ? offsets::LocalScriptEmbedded : offsets::ModuleScriptEmbedded;
        std::uintptr_t embeddedPtr = read_memory<std::uintptr_t>(_Self + embeddedSourceOffset, handle);

        if (revertBytecode) {
            std::uintptr_t originalBytecodePtr = read_memory<std::uintptr_t>(embeddedPtr + offsets::Bytecode, handle);
            std::uint64_t originalSize = read_memory<std::uint64_t>(embeddedPtr + offsets::BytecodeSize, handle);

            std::thread([embeddedPtr, originalBytecodePtr, originalSize, handle = this->handle]() {
                Sleep(850);
                write_memory<std::uintptr_t>(embeddedPtr + offsets::Bytecode, originalBytecodePtr, handle);
                write_memory<std::uint64_t>(embeddedPtr + offsets::BytecodeSize, originalSize, handle);
                }).detach();
        }

        LPVOID allocatedAddress = VirtualAllocEx(handle, nullptr, compressedBytecode.size(), MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
        if (allocatedAddress == 0)
            return false;

        DWORD oldProtection;
        DWORD d;

        VirtualProtectEx(handle, allocatedAddress, sizeof(compressedBytecode.c_str()), PAGE_READWRITE, &oldProtection);
        NtWriteVirtualMemory(handle, allocatedAddress, (PVOID)compressedBytecode.c_str(), (ULONG)compressedBytecode.size(), nullptr);

        return VirtualProtectEx(handle, allocatedAddress, sizeof(compressedBytecode.c_str()), oldProtection, &d)
            && write_memory<std::uintptr_t>(embeddedPtr + offsets::Bytecode, reinterpret_cast<std::uintptr_t>(allocatedAddress), handle)
            && write_memory<std::uint64_t>(embeddedPtr + offsets::BytecodeSize, compressedBytecode.size(), handle);
    }

    std::string GetBytecode() const;

    void UnlockModule() const {
        if (ClassName() == "ModuleScript") {
            write_memory<std::uintptr_t>(Self() + offsets::ModuleFlags, 0x100000000, handle);
            write_memory<std::uintptr_t>(Self() + offsets::IsCoreScript, 0x1, handle);
        }
    }

    std::vector<std::string> GetProperties() const {
        std::vector<std::string> Properties;
        {
            std::uintptr_t ClassDescriptor = read_memory<std::uintptr_t>(_Self + offsets::ClassDescriptor, handle);

            std::uintptr_t PropertiesStart = read_memory<std::uintptr_t>(ClassDescriptor + 0x28, handle);
            std::uintptr_t PropertiesEnd = read_memory<std::uintptr_t>(ClassDescriptor + 0x30, handle);

            for (std::uintptr_t PropertyAddress = PropertiesStart; PropertyAddress < PropertiesEnd; PropertyAddress += 0x8) {
                std::uintptr_t PropertyPtr = read_memory<std::uintptr_t>(PropertyAddress, handle);
                if (PropertyPtr != 0)
                    Properties.push_back(functions::ReadRobloxString(read_memory<std::uintptr_t>(PropertyPtr + 0x8, handle), handle));
            }
        }
        return Properties;
    }

    // Variables
    inline std::uintptr_t Self() const {
        return _Self;
    }

    inline std::string Name() const {
        return functions::ReadRobloxString(read_memory<std::uintptr_t>(_Self + offsets::Name, handle), handle);
    }

    inline std::string ClassName() const {
        return functions::ReadRobloxString(read_memory<std::uintptr_t>(read_memory<std::uintptr_t>(_Self + offsets::ClassDescriptor, handle) + offsets::ClassName, handle), handle);
    }

    inline std::uintptr_t ParentAddress() const {
        return read_memory<std::uintptr_t>(_Self + offsets::Parent, handle);
    }

    inline std::unique_ptr<Instance> Parent() const {
        return std::make_unique<Instance>(ParentAddress(), handle);
    }
};

class RBXClient {
private:
    HANDLE handle;
    std::uintptr_t RenderView{};
public:
    std::string Username = "N/A";
    std::string Version = "";
    std::string GUID;
    DWORD PID;

    std::string TeleportQueue;
    std::filesystem::path ClientDir;

    RBXClient(DWORD processID);

    inline bool isProcessAlive() const {
        DWORD exitCode;
        if (GetExitCodeProcess(handle, &exitCode)) {
            return exitCode == STILL_ACTIVE;
        }
        return false;
    }

    inline std::uintptr_t FetchDataModel() const {
        std::uintptr_t fakeDataModel = read_memory<std::uintptr_t>(RenderView + 0x118, handle);
        if (fakeDataModel == 0)
            std::cerr << "Could not fetch datamodel, expect a crash\n";
        return fakeDataModel + 0x190;
    }

    void execute(const std::string& source) const;
    bool loadstring(const std::string& source, const std::string& script_name, const std::string& chunk_name) const;

    void UnlockModule(const std::string_view objectval_name) const {
        std::uintptr_t scriptPtr = RBXClient::GetObjectValuePtr(objectval_name);
        if (scriptPtr == 0)
            return;

        return Instance(scriptPtr, handle).UnlockModule();
    }

    std::string GetBytecode(const std::string_view objectval_name) const {
        std::uintptr_t scriptPtr = RBXClient::GetObjectValuePtr(objectval_name);
        if (scriptPtr == 0)
            return "";

        return Instance(scriptPtr, handle).GetBytecode();
    }

    void SpoofInstance(const std::string_view objectval_name, std::uintptr_t new_address) const {
        std::uintptr_t instancePtr = RBXClient::GetObjectValuePtr(objectval_name);
        if (instancePtr == 0)
            return;

        write_memory<std::uintptr_t>(instancePtr + offsets::This, new_address, handle);
    }

    std::vector<std::string> GetProperties(const std::string_view objectval_name) const {
        std::uintptr_t instancePtr = RBXClient::GetObjectValuePtr(objectval_name);
        if (instancePtr == 0)
            return {};

        return Instance(instancePtr, handle).GetProperties();
    }

    std::uintptr_t GetObjectValuePtr(std::string_view objectval_name) const;
};

struct ClientInfo {
    const char* Version;
    const char* Username;
    int ProcessID;
};

class bytecode_encoder_t : public Luau::BytecodeEncoder {
    inline void encode(uint32_t* data, size_t count) override {
        for (auto i = 0u; i < count;) {
            auto& opcode = *reinterpret_cast<uint8_t*>(data + i);
            i += Luau::getOpLength(LuauOpcode(opcode));
            opcode *= 227;
        }
    }
};

std::vector<DWORD> GetProcessIDsByName(const std::wstring_view processName);
std::uintptr_t GetRV(HANDLE handle);

std::string compilable(const std::string& source, bool returnBytecode = false);
std::string Compile(const std::string& source);
std::string decompress(const std::string_view compressed);

HWND GetHWNDFromPID(DWORD process_id);