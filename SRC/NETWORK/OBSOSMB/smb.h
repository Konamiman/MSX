//
// smb.h
//
// Original at: http://www.jbox.dk/sanos/source/sys/fs/smbfs/smb.h.html
// Copyright (C) 2002 Michael Ringgaard. All rights reserved.
// 
// Adapted for SMBSERV by Konamiman
//

#ifndef SMB_H
#define SMB_H

typedef struct {
    unsigned long low;
    unsigned long high;
} __int64;

#define ROUNDUP(x) (((x) + 3) & ~3)

#define SMB_DIRBUF_SIZE         4096

#define MAXPATH 64

#define EPOC                    116444736000000000     // 00:00:00 GMT on January 1, 1970
#define SECTIMESCALE            10000000               // 1 sec resolution

#define SMB_HEADER_LEN 35

#define CAP_RPC_REMOTE_APIS             ((unsigned long)0x20)
#define CAP_NT_SMBS						((unsigned long)0x10)

#define TRANS_WAIT_NMPIPE				((unsigned short)0x0053)
#define TRANS_TRANSACT_NMPIPE			((unsigned short)0x0026)

// Miscellaneous flags and request/response field values

#define SMB_SETUP_GUEST                ((unsigned short)0x0001)
#define TREE_CONNECT_ANDX_DISCONNECT_TID ((unsigned short)0x0001)
#define REQ_ATTRIB                     ((unsigned short)0x0001)
#define SMB_DA_ACCESS_READ             ((unsigned short)0x0000)
#define SMB_DA_ACCESS_WRITE            ((unsigned short)0x0001)
#define SMB_DA_ACCESS_READ_WRITE       ((unsigned short)0x0002)
#define FileTypeDisk                   ((unsigned short)0x0000)
#define FileTypeMessageModePipe        ((unsigned short)0x0002)
#define OpenResult_FileExistedAndWasOpened        ((unsigned short)0x0001)
#define OpenResult_FileWasCreated      ((unsigned short)0x0002)
#define OpenResult_FileWasTruncated    ((unsigned short)0x0003)
#define NmStatus_MessageReadMode       ((unsigned short)0x0100)
#define NmStatus_MessageOpenMode       ((unsigned short)0x0400)
#define TRANS_TRANSACT_NMPIPE   	   ((unsigned short)0x0026)

//
// SMB header flags
//

#define SMB_FLAGS_LOCK_AND_READ         0x01
#define SMB_FLAGS_BUF_AVAIL             0x02
#define SMB_FLAGS_CASE_INSENSITIVE      0x08
#define SMB_FLAGS_CANONICALIZED_PATHS   0x10
#define SMB_FLAGS_OPLOCK                0x20
#define SMB_FLAGS_OPBATCH               0x40
#define SMB_FLAGS_REPLY                 0x80


#define SMB_FLAGS2_LONG_NAMES           0x0001
#define SMB_FLAGS2_EAS                  0x0002
#define SMB_FLAGS2_SMB_SECURITY_SIGNATURE 0x0004
#define SMB_FLAGS2_IS_LONG_NAME         0x0040
#define SMB_FLAGS2_DFS                  0x1000
#define SMB_FLAGS2_PAGING_IO            0x2000
#define SMB_FLAGS2_NT_STATUS            0x4000
#define SMB_FLAGS2_UNICODE              0x8000


//
// SMB Command Codes
//

#define SMB_COM_CREATE_DIRECTORY        0x00
#define SMB_COM_DELETE_DIRECTORY        0x01
#define SMB_COM_OPEN                    0x02
#define SMB_COM_CREATE                  0x03
#define SMB_COM_CLOSE                   0x04
#define SMB_COM_FLUSH                   0x05
#define SMB_COM_DELETE                  0x06
#define SMB_COM_RENAME                  0x07
#define SMB_COM_QUERY_INFORMATION       0x08
#define SMB_COM_SET_INFORMATION         0x09
#define SMB_COM_READ                    0x0A
#define SMB_COM_WRITE                   0x0B
#define SMB_COM_LOCK_BYTE_RANGE         0x0C
#define SMB_COM_UNLOCK_BYTE_RANGE       0x0D
#define SMB_COM_CREATE_TEMPORARY        0x0E
#define SMB_COM_CREATE_NEW              0x0F
#define SMB_COM_CHECK_DIRECTORY         0x10
#define SMB_COM_PROCESS_EXIT            0x11
#define SMB_COM_SEEK                    0x12
#define SMB_COM_LOCK_AND_READ           0x13
#define SMB_COM_WRITE_AND_UNLOCK        0x14
#define SMB_COM_READ_RAW                0x1A
#define SMB_COM_READ_MPX                0x1B
#define SMB_COM_READ_MPX_SECONDARY      0x1C
#define SMB_COM_WRITE_RAW               0x1D
#define SMB_COM_WRITE_MPX               0x1E
#define SMB_COM_WRITE_COMPLETE          0x20
#define SMB_COM_SET_INFORMATION2        0x22
#define SMB_COM_QUERY_INFORMATION2      0x23
#define SMB_COM_LOCKING_ANDX            0x24
#define SMB_COM_TRANSACTION             0x25
#define SMB_COM_TRANSACTION_SECONDARY   0x26
#define SMB_COM_IOCTL                   0x27
#define SMB_COM_IOCTL_SECONDARY         0x28
#define SMB_COM_COPY                    0x29
#define SMB_COM_MOVE                    0x2A
#define SMB_COM_ECHO                    0x2B
#define SMB_COM_WRITE_AND_CLOSE         0x2C
#define SMB_COM_OPEN_ANDX               0x2D
#define SMB_COM_READ_ANDX               0x2E
#define SMB_COM_WRITE_ANDX              0x2F
#define SMB_COM_CLOSE_AND_TREE_DISC     0x31
#define SMB_COM_TRANSACTION2            0x32
#define SMB_COM_TRANSACTION2_SECONDARY  0x33
#define SMB_COM_FIND_CLOSE2             0x34
#define SMB_COM_FIND_NOTIFY_CLOSE       0x35
#define SMB_COM_TREE_CONNECT            0x70
#define SMB_COM_TREE_DISCONNECT         0x71
#define SMB_COM_NEGOTIATE               0x72
#define SMB_COM_SESSION_SETUP_ANDX      0x73
#define SMB_COM_LOGOFF_ANDX             0x74
#define SMB_COM_TREE_CONNECT_ANDX       0x75
#define SMB_COM_QUERY_INFORMATION_DISK  0x80
#define SMB_COM_SEARCH                  0x81
#define SMB_COM_FIND                    0x82
#define SMB_COM_FIND_UNIQUE             0x83
#define SMB_COM_NT_TRANSACT             0xA0
#define SMB_COM_NT_TRANSACT_SECONDARY   0xA1
#define SMB_COM_NT_CREATE_ANDX          0xA2
#define SMB_COM_NT_CANCEL               0xA4
#define SMB_COM_OPEN_PRINT_FILE         0xC0
#define SMB_COM_WRITE_PRINT_FILE        0xC1
#define SMB_COM_CLOSE_PRINT_FILE        0xC2
#define SMB_COM_GET_PRINT_QUEUE         0xC3
#define SMB_COM_READ_BULK               0xD8
#define SMB_COM_WRITE_BULK              0xD9
#define SMB_COM_WRITE_BULK_DATA         0xDA
#define SMB_COM_INVALID                 0xFE
#define SMB_COM_NO_ANDX_COMMAND         0xFF

//
// SMB TRANS2 sub commands
//

#define TRANS2_OPEN2                    0x00    // Create file with extended attributes
#define TRANS2_FIND_FIRST2              0x01    // Begin search for files
#define TRANS2_FIND_NEXT2               0x02    // Resume search for files
#define TRANS2_QUERY_FS_INFORMATION     0x03    // Get file system information
#define TRANS2_QUERY_PATH_INFORMATION   0x05    // Get information about a named file or directory
#define TRANS2_SET_PATH_INFORMATION     0x06    // Set information about a named file or directory
#define TRANS2_QUERY_FILE_INFORMATION   0x07    // Get information about a handle
#define TRANS2_SET_FILE_INFORMATION     0x08    // Set information by handle
#define TRANS2_FSCTL                    0x09    // Not implemented by NT server
#define TRANS2_IOCTL2                   0x0A    // Not implemented by NT server
#define TRANS2_FIND_NOTIFY_FIRST        0x0B    // Not implemented by NT server
#define TRANS2_FIND_NOTIFY_NEXT         0x0C    // Not implemented by NT server
#define TRANS2_CREATE_DIRECTORY         0x0D    // Create directory with extended attributes
#define TRANS2_SESSION_SETUP            0x0E    // Session setup with extended security information
#define TRANS2_GET_DFS_REFERRAL         0x10    // Get a DFS referral
#define TRANS2_REPORT_DFS_INCONSISTENCY 0x11    // Report a DFS knowledge inconsistency

//
// SMB protocol capability flags
//

#define SMB_CAP_RAW_MODE                0x0001
#define SMB_CAP_MPX_MODE                0x0002
#define SMB_CAP_UNICODE                 0x0004
#define SMB_CAP_LARGE_FILES             0x0008
#define SMB_CAP_NT_SMBS                 0x0010
#define SMB_CAP_RPC_REMOTE_APIS         0x0020
#define SMB_CAP_STATUS32                0x0040
#define SMB_CAP_LEVEL_II_OPLOCKS        0x0080
#define SMB_CAP_LOCK_AND_READ           0x0100
#define SMB_CAP_NT_FIND                 0x0200
#define SMB_CAP_DFS                     0x1000
#define SMB_CAP_LARGE_READX             0x4000

//
// SMB file attributes and flags
//

#define SMB_FILE_ATTR_ARCHIVE           0x020   // The file has not been archived since it was last modified.
//#define SMB_FILE_ATTR_COMPRESSED        0x800   // The file or directory is compressed. 
#define SMB_FILE_ATTR_NORMAL            0x000   // The file has no other attributes set. 
#define SMB_FILE_ATTR_HIDDEN            0x002   // The file is hidden. 
#define SMB_FILE_ATTR_READONLY          0x001   // The file is read only. 
//#define SMB_FILE_ATTR_TEMPORARY         0x100   // The file is temporary
#define SMB_FILE_ATTR_DIRECTORY         0x010   // The file is a directory
#define SMB_FILE_ATTR_SYSTEM            0x004   // The file is part of or is used exclusively by the operating system.
#define SMB_FILE_ATTR_VOLUME            0x008   // The file is part of or is used exclusively by the operating system.

#define SMB_SEARCH_ATTRIBUTE_READONLY   0x0100
#define SMB_SEARCH_ATTRIBUTE_HIDDEN     0x0200
#define SMB_SEARCH_ATTRIBUTE_SYSTEM     0x0400
#define SMB_SEARCH_ATTRIBUTE_DIRECTORY  0x1000
#define SMB_SEARCH_ATTRIBUTE_ARCHIVE    0x2000

#define SMB_FILE_FLAG_WRITE_THROUGH     0x80000000
#define SMB_FILE_FLAG_NO_BUFFERING      0x20000000
#define SMB_FILE_FLAG_RANDOM_ACCESS     0x10000000
#define SMB_FILE_FLAG_SEQUENTIAL_SCAN   0x08000000
#define SMB_FILE_FLAG_DELETE_ON_CLOSE   0x04000000
#define SMB_FILE_FLAG_BACKUP_SEMANTICS  0x02000000
#define SMB_FILE_FLAG_POSIX_SEMANTICS   0x01000000

//
// SMB access mask
//

#define SMB_ACCESS_DELETE               0x00010000
#define SMB_ACCESS_READ_CONTROL         0x00020000
#define SMB_ACCESS_WRITE_DAC            0x00040000
#define SMB_ACCESS_WRITE_OWNER          0x00080000
#define SMB_ACCESS_SYNCHRONIZE          0x00100000

#define SMB_ACCESS_GENERIC_READ         0x80000000
#define SMB_ACCESS_GENERIC_WRITE        0x40000000
#define SMB_ACCESS_GENERIC_EXECUTE      0x20000000
#define SMB_ACCESS_GENERIC_ALL          0x10000000

//
// SMB file sharing access
//

#define SMB_FILE_SHARE_READ             0x00000001
#define SMB_FILE_SHARE_WRITE            0x00000002
#define SMB_FILE_SHARE_DELETE           0x00000004

//
// SMB file create disposition
//

#define SMB_OPEN_EXISTING       1       // Fail if not exist, open if exists
#define SMB_CREATE_NEW          2       // Create if not exist, fail if exist
#define SMB_OPEN_ALWAYS         3       // Create if not exist, open if exists
#define SMB_TRUNCATE_EXISTING   4       // Fail if not exist, truncate if exists
#define SMB_CREATE_ALWAYS       5       // Create if not exist, trunc if exist

//
// SMB impersonation levels
//

#define SMB_SECURITY_ANONYMOUS          0
#define SMB_SECURITY_IDENTIFICATION     1
#define SMB_SECURITY_IMPERSONATION      2
#define SMB_SECURITY_DELEGATION         3

//
// SMB filesystem information levels
//

#define SMB_INFO_ALLOCATION             1
#define SMB_INFO_VOLUME                 2
#define SMB_QUERY_FS_VOLUME_INFO        0x102
#define SMB_QUERY_FS_SIZE_INFO          0x103
#define SMB_QUERY_FS_DEVICE_INFO        0x104
#define SMB_QUERY_FS_ATTRIBUTE_INFO     0x105

//
// SMB file information levels
//

#define SMB_INFO_STANDARD               1
#define SMB_INFO_QUERY_EA_SIZE          2
#define SMB_INFO_QUERY_EAS_FROM_LIST    3
#define SMB_INFO_QUERY_ALL_EAS          4
#define SMB_INFO_IS_NAME_VALID          6
#define SMB_QUERY_FILE_BASIC_INFO       0x101
#define SMB_QUERY_FILE_STANDARD_INFO    0x102
#define SMB_QUERY_FILE_EA_INFO          0x103
#define SMB_QUERY_FILE_NAME_INFO        0x104
#define SMB_QUERY_FILE_ALL_INFO         0x107
#define SMB_QUERY_FILE_ALT_NAME_INFO    0x108
#define SMB_QUERY_FILE_STREAM_INFO      0x109
#define SMB_QUERY_FILE_COMPRESSION_INFO 0x10B

//
// SMB find information levels
//

//#define SMB_INFO_STANDARD 0x0001
//#define SMB_INFO_QUERY_EA_SIZE 0x0002
//#define SMB_INFO_QUERY_EAS_FROM_LIST 0x0003
#define SMB_FIND_FILE_DIRECTORY_INFO 0x0101
#define SMB_FIND_FILE_FULL_DIRECTORY_INFO 0x0102
#define SMB_FIND_FILE_NAMES_INFO 0x0103
#define SMB_FIND_FILE_BOTH_DIRECTORY_INFO 0x0104

//
// FindFirst/FindNext flags
//

#define SMB_CLOSE_AFTER_FIRST           (1 << 0)
#define SMB_CLOSE_IF_END                (1 << 1)
#define SMB_REQUIRE_RESUME_KEY          (1 << 2)
#define SMB_CONTINUE_BIT                (1 << 3)

//
// Error Classes
//

#define SUCCESS             0       // The request was successful.
#define ERRDOS              0x01    // Error is from the core DOS operating system set.
#define ERRSRV              0x02    // Error is generated by the server network file manager.
#define ERRHRD              0x03    // Error is an hardware error.
#define ERRCMD              0xFF    // Command was not in the "SMB" format.

//
// SMB X/Open error codes for the ERRdos error class
//

#define ERRbadfunc              1       // Invalid function (or system call)
#define ERRbadfile              2       // File not found (pathname error)
#define ERRbadpath              3       // Directory not found
#define ERRnofids               4       // Too many open files
#define ERRnoaccess             5       // Access denied
#define ERRbadfid               6       // Invalid fid
#define ERRbadmcb               7       // Memory control blocks destroyed
#define ERRnomem                8       // Out of memory
#define ERRbadmem               9       // Invalid memory block address
#define ERRbadenv               10      // Invalid environment
#define ERRbadformat            11      // Invalid format
#define ERRbadaccess            12      // Invalid open mode
#define ERRbaddata              13      // Invalid data (only from ioctl call)
#define ERRres                  14      // Reserved
#define ERRbaddrive             15      // Invalid drive
#define ERRremcd                16      // Attempt to delete current directory
#define ERRdiffdevice           17      // Rename/move across different filesystems
#define ERRnofiles              18      // No more files found in file search
#define ERRbadshare             32      // Share mode on file conflict with open mode
#define ERRlock                 33      // Lock request conflicts with existing lock
#define ERReof                  0x26
#define ERRunsup                0x32
#define ERRfilexists            80      // File in operation already exists
#define ERRinvalidparam         0x57
#define ERRundocumented1        123     // Invalid name?? e.g. .tmp*
#define ERRbadpipe              230     // Named pipe invalid
#define ERRpipebusy             231     // All instances of pipe are busy
#define ERRpipeclosing          232     // Named pipe close in progress
#define ERRnotconnected         233     // No process on other end of named pipe
#define ERRmoredata             234     // More data to be returned

//
// Error codes for the ERRSRV class
//

#define ERRerror                1       // Non specific error code
#define ERRbadpw                2       // Bad password
#define ERRbadtype              3       // Reserved
#define ERRaccess               4       // No permissions to do the requested operation
#define ERRinvtid               5       // Tid invalid
#define ERRinvnetname           6       // Invalid servername
#define ERRinvdevice            7       // Invalid device
#define ERRqfull                49      // Print queue full
#define ERRqtoobig              50      // Queued item too big
#define ERRinvpfid              52      // Invalid print file in smb_fid
#define ERRsmbcmd               64      // Unrecognised command
#define ERRsrverror             65      // SMB server internal error
#define ERRfilespecs            67      // Fid and pathname invalid combination
#define ERRbadlink              68      // Reserved
#define ERRbadpermits           69      // Access specified for a file is not valid
#define ERRbadpid               70      // Reserved
#define ERRsetattrmode          71      // Attribute mode invalid
#define ERRpaused               81      // Message server paused
#define ERRmsgoff               82      // Not receiving messages
#define ERRnoroom               83      // No room for message
#define ERRrmuns                87      // Too many remote usernames
#define ERRtimeout              88      // Operation timed out
#define ERRnoresource           89      // No resources currently available for request.
#define ERRtoomanyuids          90      // Too many userids
#define ERRbaduid               91      // Bad userid
#define ERRuseMPX               250     // Temporarily unable to use raw mode, use MPX mode
#define ERRuseSTD               251     // Temporarily unable to use raw mode, use std.mode
#define ERRcontMPX              252     // Resume MPX mode
#define ERRnosupport            0xFFFF

//
// Error codes for the ERRHRD class
//

#define ERRnowrite              19      // Read only media
#define ERRbadunit              20      // Unknown device
#define ERRnotready             21      // Drive not ready
#define ERRbadcmd               22      // Unknown command
#define ERRdata                 23      // Data (CRC) error
#define ERRbadreq               24      // Bad request structure length
#define ERRseek                 25
#define ERRbadmedia             26
#define ERRbadsector            27
#define ERRnopaper              28
#define ERRwrite                29      // Write fault
#define ERRread                 30      // Read fault
#define ERRgeneral              31      // General hardware failure
#define ERRwrongdisk            34
#define ERRFCBunavail           35
#define ERRsharebufexc          36      // Share buffer exceeded
#define ERRdiskfull             39


typedef __int64 smb_size;
typedef __int64 long smb_time;

struct smb_pos
{
  unsigned long low_part;
  unsigned long high_part;
};

//
// SMB ANDX structure
//

struct smb_andx
{
  unsigned char cmd;                    // Secondary (X) command; 0xFF = none
  unsigned char reserved;               // Reserved (must be 0)
  unsigned short offset;                // Offset to next command WordCount
};

//
// SMB NEGOTIATE response parameters
//

struct smb_negotiate_response
{
  unsigned short dialect_index;         // Index of selected dialect
  unsigned char security_mode;          // Security mode:
                                        //   bit 0: 0 = share, 1 = user
                                        //   bit 1: 1 = encrypt passwords
                                        //   bit 2: 1 = Security Signatures (SMB sequence numbers) enabled
                                        //   bit 3: 1 = Security Signatures (SMB sequence numbers) required
  unsigned short max_mpx_count;         // Max pending multiplexed requests
  unsigned short max_number_vcs;        // Max VCs between client and server
  unsigned long max_buffer_size;        // Max transmit buffer size
  unsigned long max_raw_size;           // Maximum raw buffer size
  unsigned long session_key;            // Unique token identifying this session
  unsigned long capabilities;           // Server capabilities
  unsigned long systemtime_low;         // System (UTC) time of the server (low).
  unsigned long systemtime_high;        // System (UTC) time of the server (high).
  short server_timezone;                // Time zone of server (min from UTC)
  unsigned char encryption_key_length;  // Length of encryption key.
};

//
// SMB SESSION SETUP request parameters
//

struct smb_session_setup_request
{
  //struct smb_andx andx;
  unsigned short max_buffer_size;         // Client maximum buffer size
  unsigned short max_mpx_count;           // Actual maximum multiplexed pending requests
  unsigned short vc_number;               // 0 = first (only), nonzero=additional VC number
  unsigned long session_key;              // Session key (valid iff VcNumber != 0)
  unsigned short ansi_password_length;    // Account password size (ansi, case insensitive)
  unsigned short unicode_password_length; // Account password size (unicode, case sensitive)
  unsigned long reserved;                 // Must be 0
  unsigned long capabilities;             // Client capabilities
};

//
// SMB SESSION SETUP response parameters
//

struct smb_session_setup_response
{
  struct smb_andx andx;
  unsigned short action;                  // Request mode: bit0 = logged in as client
};

//
// SMB TREE CONNECT request parameters
//

struct smb_tree_connect_request
{
  //struct smb_andx andx;
  unsigned short flags;                   // Additional information; bit 0 set = disconnect tid
  unsigned short password_length;         // Length of password[]
};

//
// SMB TREE CONNECT response parameters
//

struct smb_tree_connect_response
{
  //struct smb_andx andx;
  unsigned short optional_support;        // Optional support bits
  //unsigned long max_access_rights;
  //unsigned long guest_max_access_rights;

};

//
// SMB CREATE FILE request parameters
//

struct smb_create_file_request
{
  struct smb_andx andx;
  unsigned char reserved;               // Reserved (must be 0)
  unsigned short name_length;           // Length of name[] in bytes
  unsigned long flags;                  // Create bit set:
                                        //   0x02 - Request an oplock
                                        //   0x04 - Request a batch oplock
                                        //   0x08 - Target of open must be directory
  unsigned long root_directory_fid;     // If non-zero, open is relative to this directory
  unsigned long desired_access;         // Access desired
  smb_size allocation_size;             // Initial allocation size
  unsigned long ext_file_attributes;    // File attributes
  unsigned long share_access;           // Type of share access
  unsigned long create_disposition;     // Action to take if file exists or not
  unsigned long create_options;         // Options to use if creating a file
  unsigned long impersonation_level;    // Security QOS information
  unsigned char security_flags;         // Security tracking mode flags:
                                        //   0x1 - SECURITY_CONTEXT_TRACKING
                                        //   0x2 - SECURITY_EFFECTIVE_ONLY
};

//
// SMB CREATE FILE response parameters
//

struct smb_create_file_response
{
  struct smb_andx andx;
  unsigned char oplock_level;           // The oplock level granted
                                        //   0 - No oplock granted
                                        //   1 - Exclusive oplock granted
                                        //   2 - Batch oplock granted
                                        //   3 - Level II oplock granted
  unsigned short fid;                   // The file ID
  unsigned long create_action;          // The action taken
  smb_time creation_time;               // The time the file was created
  smb_time last_access_time;            // The time the file was accessed
  smb_time last_write_time;             // The time the file was last written
  smb_time change_time;                 // The time the file was last changed
  unsigned long ext_file_attributes;    // The file attributes
  smb_size allocation_size;             // The number of byes allocated
  smb_size end_of_file;                 // The end of file offset
  unsigned short file_type;     
  unsigned short device_state;          // State of IPC device (e.g. pipe)
  unsigned char directory;              // TRUE if this is a directory
};


//
// SMB OPEN_ANDX request parameters
//

struct smb_open_file_request
{
  unsigned short flags;
  unsigned short access_mode;
  unsigned short search_attributes;
  unsigned short file_attributes;
  unsigned long creation_time;
  unsigned short open_mode;
  unsigned long allocation_size;
  unsigned long timeout;
  unsigned long reserved;
};


//
// SMB OPEN_ANDX response parameters
//

struct smb_open_file_response
{
  unsigned short fid;
  unsigned short file_attributes;
  unsigned long last_write_time;
  unsigned long file_data_size;
  unsigned short access_rights;
  unsigned short resource_type;
  unsigned short nm_pipe_status;
  unsigned short open_results;
  byte reserved[6];
};


//
// SMB CLOSE FILE request parameters
//

struct smb_close_file_request
{
  unsigned short fid;                     // File handle
  smb_time last_write_time;               // Time of last write
};

//
// SMB FLUSH FILE request parameters
//

struct smb_flush_file_request
{
  unsigned short fid;                     // File handle
};

//
// SMB READ FILE request parameters
//

struct smb_read_file_andx_request
{
  //struct smb_andx andx;
  unsigned short fid;                   // File handle
  unsigned long offset;                 // Offset in file to begin read
  unsigned short max_count;             // Max number of bytes to return
  unsigned short min_count;             // Reserved
  unsigned long reserved;               // Must be 0
  unsigned short remaining;             // Reserved
  unsigned long offset_high;            // Upper 32 bits of offset (only if wordcount is 12)
};

//
// SMB READ FILE response parameters
//

struct smb_read_file_andx_response
{
  //struct smb_andx andx;
  short remaining;             // Reserved -- must be -1
  unsigned short data_compaction_mode;  
  unsigned short reserved1;             // Reserved (must be 0)
  unsigned short data_length;           // Number of data bytes (min = 0)
  unsigned short data_offset;           // Offset (from header start) to data
  unsigned short reserved2[5];          // Reserved (must be 0)
};

//
// SMB READ FILE RAW request parameters
//

struct smb_read_raw_request
{
  unsigned short fid;                   // File handle
  unsigned long offset;                 // Offset in file to begin read
  unsigned short max_count;             // Max number of bytes to return
  unsigned short min_count;             // Reserved
  unsigned long timeout;                // Wait timeout if named pipe
  unsigned short reserved;              // Reserved
};


//
// SMB WRITE FILE request parameters
//

struct smb_write_file_request
{
  unsigned short fid;                   // File handle
  unsigned short data_length;           // Number of data bytes in buffer (>= 0)
  unsigned long offset;                 // Offset in file to begin read
  unsigned short estimated_remaining;
};

//
// SMB WRITE FILE response parameters
//

struct smb_write_file_response
{
  unsigned short count;                 // Number of bytes written
};

//
// SMB WRITE FILE ANDX request parameters
//

struct smb_write_file_andx_request
{
  //struct smb_andx andx;
  unsigned short fid;                   // File handle
  unsigned long offset;                 // Offset in file to begin read
  unsigned long reserved1;              // Must be 0
  unsigned short write_mode;            // Write mode bits: 0 - write through
  unsigned short remaining;             // Reserved
  unsigned short reserved2;             // Must be 0
  unsigned short data_length;           // Number of data bytes in buffer (>= 0)
  unsigned short data_offset;           // Offset to data bytes
  unsigned long offset_high;            // Upper 32 bits of offset (Only if wordcount is 14)
};

//
// SMB WRITE FILE ANDX response parameters
//

struct smb_write_file_andx_response
{
  //struct smb_andx andx;
  unsigned short count;                 // Number of bytes written
  unsigned short remaining;             // Reserved -- must be -1
  unsigned short reserved;              // Reserved (must be 0)
};

//
// SMB RENAME request parameters
//

struct smb_rename_request
{
  unsigned short search_attributes;     // Target file attributes
};

//
// SMB DELETE request parameters
//

struct smb_delete_request
{
  unsigned short search_attributes;     // Target file attributes
};

//
// SMB COPY request parameters
//

struct smb_copy_request
{
  unsigned short tid2;                  // Second (target) path TID
  unsigned short open_function;         // What to do if target file exists
  unsigned short flags;                 // Flags to control copy operation:
                                        //   bit 0 - target must be a file
                                        //   bit 1 - target must be a dir.
                                        //   bit 2 - copy target mode: 0 = binary, 1 = ASCII
                                        //   bit 3 - copy source mode: 0 = binary, 1 = ASCII
                                        //   bit 4 - verify all writes
                                        //   bit 5 - tree copy
};

//
// SMB COPY response parameters
//

struct smb_copy_response
{
  unsigned short count;                 // Number of files copied
};

//
// SMB FINDCLOSE2 request parameters
//

struct smb_findclose_request
{
  unsigned short sid;                   // Search handle
};

//
// SMB CLOSE request parameters
//

struct smb_close_request
{
	unsigned short fid;
	unsigned short last_time_modified;
};

//
// SMB TRANSACTION request parameters
//

struct smb_trans_request
{
  unsigned short total_parameter_count; // Total parameter bytes being sent
  unsigned short total_data_count;      // Total data bytes being sent
  unsigned short max_parameter_count;   // Max parameter bytes to return
  unsigned short max_data_count;        // Max data bytes to return
  unsigned char max_setup_count;        // Max setup words to return
  unsigned char reserved;
  unsigned short flags;                 // Additional information: bit 0 - also disconnect TID in Tid
  unsigned long timeout;
  unsigned short reserved2;
  unsigned short parameter_count;       // Parameter bytes sent this buffer
  unsigned short parameter_offset;      // Offset (from header start) to Parameters
  unsigned short data_count;            // Data bytes sent this buffer
  unsigned short data_offset;           // Offset (from header start) to data
  unsigned char setup_count;            // Count of setup words
  unsigned char reserved3;              // Reserved (pad above to word)
  unsigned short setup;              // Setup words (# = SetupWordCount)
};

//
// SMB TRANSACTION response parameters
//

struct smb_trans_response
{
  unsigned short total_parameter_count; // Total parameter bytes being sent
  unsigned short total_data_count;      // Total data bytes being sent
  unsigned short reserved;              
  unsigned short parameter_count;       // Parameter bytes sent this buffer
  unsigned short parameter_offset;      // Offset (from header start) to Parameters
  unsigned short parameter_displacement;// Displacement of these Parameter bytes
  unsigned short data_count;            // Data bytes sent this buffer
  unsigned short data_offset;           // Offset (from header start) to data
  unsigned short data_displacement;     // Displacement of these data bytes
  unsigned char setup_count;            // Count of setup words
  unsigned char reserved2;              // Reserved (pad above to word)
  unsigned short setup;              // Setup words (# = SetupWordCount)
};

//
// Server Message Block (SMB)
//

struct smb
{
  //unsigned char len[4];                // Length field
  unsigned char protocol[4];           // Always 0xFF,'SMB'
  unsigned char cmd;                   // Command
  unsigned char error_class;           // Error Class
  unsigned char reserved;              // Reserved
  unsigned short error;                // Error Code
  unsigned char flags;                 // Flags
  unsigned short flags2;               // More flags
  unsigned short pidhigh;              // High part of PID
  unsigned char secsig[8];             // Reserved for security
  unsigned short pad;
  unsigned short tid;                  // Tree identifier
  unsigned short pid;                  // Caller's process id
  unsigned short uid;                  // Unauthenticated user id
  unsigned short mid;                  // Multiplex id
  unsigned char wordcount;             // Count of parameter words
  union
  {
    unsigned short words[0];
    struct smb_andx andx;
    union
    {
      struct smb_session_setup_request setup;
      struct smb_tree_connect_request connect;
      struct smb_create_file_request create;
      struct smb_close_file_request close;
      struct smb_flush_file_request flush;
      struct smb_read_file_andx_request read;
      struct smb_read_raw_request readraw;
      struct smb_write_file_request write;
      struct smb_trans_request trans;
      struct smb_rename_request rename;
      struct smb_delete_request del;
      struct smb_copy_request copy;
      struct smb_findclose_request findclose;
    } req;
    union
    {
      struct smb_negotiate_response negotiate;
      struct smb_session_setup_response setup;
      struct smb_tree_connect_response connect;
      struct smb_create_file_response create;
      struct smb_read_file_andx_response read;
      struct smb_write_file_response write;
      struct smb_trans_response trans;
      struct smb_copy_response copy;
    } rsp;
  } params;
};


struct smb_header
{
  unsigned char protocol[4];           // Always 0xFF,'SMB'
  unsigned char cmd;                   // Command
  unsigned char error_class;           // Error Class
  unsigned char reserved;              // Reserved
  unsigned short error;                // Error Code
  unsigned char flags;                 // Flags
  unsigned short flags2;               // More flags
  unsigned short pidhigh;              // High part of PID
  unsigned char secsig[8];             // Reserved for security
  unsigned short pad;
  unsigned short tid;                  // Tree identifier
  unsigned short pid;                  // Caller's process id
  unsigned short uid;                  // Unauthenticated user id
  unsigned short mid;                  // Multiplex id
  unsigned char wordcount;             // Count of parameter words
};

//
// SMB TRANS request and response messages
//

struct smb_fileinfo_request
{
  unsigned short fid;                   // File ID
  unsigned short infolevel;             // Information level
};

struct smb_pathinfo_request
{
  unsigned short infolevel;             // Information level
  unsigned long reserved;
  char filename[MAXPATH];
};

struct smb_set_fileinfo_request
{
  unsigned short fid;                   // File ID
  unsigned short infolevel;             // Information level
  unsigned short reserved;
};

struct smb_set_fileinfo_response
{
  unsigned short reserved;
};

struct smb_fsinfo_request
{
  unsigned short infolevel;             // Information level
};

struct smb_info_standard
{
  unsigned long resume_key;
  unsigned short creation_date;         // Date when file was created   
  unsigned short creation_time;         // Time when file was created   
  unsigned short last_access_date;      // Date of last file access     
  unsigned short last_access_time;      // Time of last file access     
  unsigned short last_write_date;       // Date of last write to the file       
  unsigned short last_write_time;       // Time of last write to the file       
  unsigned long data_size;              // File Size    
  unsigned long allocation_size;        // Size of filesystem allocation unit   
  unsigned short attributes;            // File Attributes      
  //unsigned long ea_size;                // Size of file's EA information
  unsigned char filename_length;
  char filename;
};

struct smb_info_allocation
{
  unsigned long file_system_id;         // File system identifier.  NT server always returns 0
  unsigned long sector_per_unit;        // Number of sectors per allocation unit
  unsigned long units_total;            // Total number of allocation units
  unsigned long units_avail;            // Total number of available allocation units
  unsigned short sectorsize;            // Number of bytes per sector
};

struct smb_query_information_disk_response
{
  unsigned short total_units;
  unsigned short blocks_per_unit;
  unsigned short block_size;
  unsigned short free_units;
  unsigned short reserved;
};

struct smb_file_basic_info
{
  smb_time creation_time;               // Time when file was created
  smb_time last_access_time;            // Time of last file access
  smb_time last_write_time;             // Time of last write to the file
  smb_time change_time;                 // Time when file was last changed
  unsigned long attributes;             // File Attributes
  unsigned long reserved;
};

struct smb_file_standard_info
{
  smb_size allocation_size;             // Allocated size of the file in number of bytes
  smb_size end_of_file;                 // Offset to the first free byte in the file
  unsigned long number_of_links;        // Number of hard links to the file
  unsigned char delete_pending;         // Indicates whether the file is marked for deletion
  unsigned char directory;              // Indicates whether the file is a directory
  unsigned short pad;
};

struct smb_file_all_info
{
  smb_time creation_time;               // Time when file was created
  smb_time last_access_time;            // Time of last file access
  smb_time last_write_time;             // Time of last write to the file
  smb_time change_time;                 // Time when file was last changed
  unsigned long attributes;             // File Attributes
  unsigned long reserved;
  smb_size allocation_size;             // Allocated size of the file in number of bytes
  smb_size end_of_file;                 // Offset to the first free byte in the file
  unsigned long number_of_links;        // Number of hard links to the file
  unsigned char delete_pending;         // Indicates whether the file is marked for deletion
  unsigned char directory;              // Indicates whether the file is a directory
  unsigned short pad;
  unsigned long ea_size;
  unsigned long filename_length;
  char filename;

  /*struct smb_file_basic_info basic;
  struct smb_file_standard_info standard;
  __int64 index_number;                 // A file system unique identifier
  unsigned long ea_size;                // Size of the file’s extended attributes in number of bytes
  unsigned long access_flags;           // Access that a caller has to the file; Possible values and meanings are specified below
  __int64 current_byte_offset;          // Current byte offset within the file
  unsigned long mode;                   // Current Open mode of the file handle to the file
  unsigned long alignment_requirement;  // Buffer Alignment required by device; possible values detailed below
  unsigned long file_name_length;       // Length of the file name in number of bytes
  char filename[256];    */               // Name of the file
};

struct smb_file_end_of_file_info
{
  smb_size end_of_file;                 // Offset to the first free byte in the file
};

struct smb_findfirst_request
{
  unsigned short search_attributes;     // Search attributes    
  unsigned short search_count;          // Maximum number of entries to return
  unsigned short flags;                 // Additional information:
                                        //   Bit 0 - close search after this request
                                        //   Bit 1 - close search if end of search reached
                                        //   Bit 2 - return resume keys for each entry found
                                        //   Bit 3 - continue search from previous ending place
                                        //   Bit 4 - find with backup intent
  unsigned short infolevel;             // Information level
  unsigned long search_storage_type;    
  char filename/*[MAXPATH]*/;               // Pattern for the search
};

struct smb_findfirst_response
{
  unsigned short sid;                   // Search handle
  unsigned short search_count;          // Number of entries returned
  unsigned short end_of_search;         // Was last entry returned?
  unsigned short ea_error_offset;       // Offset into EA list if EA error
  unsigned short last_name_offset;      // Offset into data to file name of last entry, if server needs it to resume search; else 0
};

struct smb_findnext_request
{
  unsigned short sid;                   // Search handle
  unsigned short search_count;          // Maximum number of entries to return
  unsigned short infolevel;             // Levels described in TRANS2_FIND_FIRST2 request
  unsigned long resume_key;             // Value returned by previous find2 call
  unsigned short flags;                 // Additional information::
                                        //   Bit 0 - close search after this request
                                        //   Bit 1 - close search if end of search reached
                                        //   Bit 2 - return resume keys for each entry found
                                        //   Bit 3 - resume/continue from previous ending place
                                        //   Bit 4 - find with backup intent
  char filename/*[1]*/;                     // Resume file name
};

struct smb_findnext_response
{
  unsigned short search_count;          // Number of entries returned
  unsigned short end_of_search;         // Was last entry returned?
  unsigned short ea_error_offset;       // Offset into EA list if EA error
  unsigned short last_name_offset;      // Offset into data to file name of last entry, if server needs it to resume search; else 0
};

struct smb_file_directory_info
{
  unsigned long next_entry_offset;      // Offset from this structure to beginning of next one
  unsigned long file_index;     
  smb_time creation_time;               // File creation time
  smb_time last_access_time;            // Last access time
  smb_time last_write_time;             // Last write time
  smb_time change_time;                 // Last attribute change time
  smb_size end_of_file;                 // File size
  smb_size allocation_size;             // Size of filesystem allocation information 
  unsigned long ext_file_attributes;    // Extended file attributes (see section 3.12)
  unsigned long filename_length;        // Length of filename in bytes
  unsigned long ea_list_length;
  char filename;                        // Name of the file (a string actually)
};


struct smb_both_file_directory_info
{
  unsigned long next_entry_offset;      // Offset from this structure to beginning of next one
  unsigned long file_index;     
  smb_time creation_time;               // File creation time
  smb_time last_access_time;            // Last access time
  smb_time last_write_time;             // Last write time
  smb_time change_time;                 // Last attribute change time
  smb_size end_of_file;                 // File size
  smb_size allocation_size;             // Size of filesystem allocation information 
  unsigned long ext_file_attributes;    // Extended file attributes (see section 3.12)
  unsigned long filename_length;        // Length of filename in bytes
  unsigned long ea_list_length;
  unsigned char short_name_length;
  unsigned char reserved;
  char short_name[24];
  char filename;                        // Name of the file (a string actually)
};

//
// SMB directory entry
//

struct smb_dentry
{
  char path[MAXPATH];
  //struct stat64 statbuf; //!!!
};

//
// SMB file
//

struct smb_file
{
  unsigned short fid;
  unsigned long attrs;
  //struct stat64 statbuf; //!!!
};

//
// SMB directory
//

struct smb_directory
{
  unsigned short sid;
  int eos;
  int entries_left;
  struct smb_file_directory_info *fi;
  char path[MAXPATH];
  char buffer[SMB_DIRBUF_SIZE];
};


struct smb_query_information2_response
{
	unsigned short create_date;
	unsigned short create_time;
	unsigned short last_access_date;
	unsigned short last_access_time;
	unsigned short last_write_date;
	unsigned short last_write_time;
	unsigned long file_size;
	unsigned long allocation_size;
	unsigned short attributes;
};

#endif
