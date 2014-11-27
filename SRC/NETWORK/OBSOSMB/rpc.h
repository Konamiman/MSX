#define NetShareEnum 15
#define NetSrvGetInfo 21

/* PDU data types and structure */

typedef     unsigned long   u_int32;
typedef     unsigned short  u_int16;
typedef     unsigned short  u_short;
typedef     unsigned char  u_int8;   /* single octet unsigned int */

#define PFC_FIRST_FRAG           0x01/* First fragment */
#define PFC_LAST_FRAG            0x02/* Last fragment */
#define PFC_PENDING_CANCEL       0x04/* Cancel was pending at sender */
#define PFC_RESERVED_1           0x08  
#define PFC_CONC_MPX             0x10/* supports concurrent multiplexing
                                        * of a single connection. */
#define PFC_DID_NOT_EXECUTE      0x20/* only meaningful on `fault' packet;
                                        * if true, guaranteed call did not
                                        * execute. */
#define PFC_MAYBE                0x40/* `maybe' call semantics requested */
#define PFC_OBJECT_UUID          0x80/* if true, a non-nil object UUID
                                        * was specified in the handle, and
                                        * is present in the optional object
                                        * field. If false, the object field
                                        * is omitted. */

typedef struct {
    byte uuid[16];
} uuid_t;

typedef enum {
    rpc_request = 0,
    rpc_response = 2,
    rpc_bind = 11,
    rpc_bind_ack = 12
} pdu_types;


typedef struct{
     /* restore 4 byte alignment */
      u_int8 auth_pad[1]; /* align(4) */ //# = auth_pad_length ???
      u_int8 auth_type; /* :01 which authent service */
      u_int8 auth_level; /* :01 which level within service */
      u_int8 auth_pad_length; /* :01 */ 
      u_int8 auth_reserved; /* :01 reserved, m.b.z. */
      u_int32 auth_context_id; /* :04 */
      u_int8 auth_value/*[0]*/; /* credentials */ //# = auth_length
} auth_verifier_co_t;


typedef   u_int16   p_context_id_t;

typedef   struct   {
             uuid_t   if_uuid;
             u_int32   if_version;
          } p_syntax_id_t;
          

typedef   struct {
          p_context_id_t   p_cont_id;
          u_int8           n_transfer_syn;     /* number of items */
          u_int8           reserved;           /* alignment pad, m.b.z. */
          p_syntax_id_t    abstract_syntax;    /* transfer syntax list */
          p_syntax_id_t    transfer_syntaxes/*[0]*/; //# = n_transfer_syn
          } p_cont_elem_t;


typedef   struct {
          u_int8          n_context_elem;      /* number of items */
          u_int8          reserved;            /* alignment pad, m.b.z. */
          u_short         reserved2;           /* alignment pad, m.b.z. */
          p_cont_elem_t   p_cont_elem/*[0]*/;      //# = n_context_elem
          } p_cont_list_t;


typedef  /*short*/ enum {
         acceptance, user_rejection, provider_rejection
         } p_cont_def_result_t;
         

typedef   /*short*/ enum {
          reason_not_specified,
          abstract_syntax_not_supported,
          proposed_transfer_syntaxes_not_supported,
          local_limit_exceeded     
          } p_provider_reason_t;

typedef struct {
        short /*p_cont_def_result_t*/   result;
        short /*p_provider_reason_t*/   reason;  /* only relevant if result !=
                                             * acceptance */
        p_syntax_id_t         transfer_syntax;/* tr syntax selected 
                                                 * 0 if result not
                                                 * accepted */
        } p_result_t;
        
        
        /* Same order and number of elements as in bind request */

typedef struct {
        u_int8   n_results;      /* count */
        u_int8   reserved;       /* alignment pad, m.b.z. */
        u_int16 reserved2;       /* alignment pad, m.b.z. */
        p_result_t p_results/*[0]*/; //# = n_results
        } p_result_list_t;
        
        typedef struct {
        u_int8   major;
        u_int8   minor;
        } version_t;


typedef   version_t   p_rt_version_t;


typedef struct {
        u_int8   n_protocols;   /* count */
        p_rt_version_t p_protocols/*[0]*/; //# = n_protocols
        } p_rt_versions_supported_t;


typedef struct {
        u_int16 length;
        char port_spec[13]; /* port string spec */ //# = length
        } port_any_t;
        
        
#define REASON_NOT_SPECIFIED            0
#define TEMPORARY_CONGESTION            1
#define LOCAL_LIMIT_EXCEEDED            2
#define CALLED_PADDR_UNKNOWN            3 /* not used */
#define PROTOCOL_VERSION_NOT_SUPPORTED  4
#define DEFAULT_CONTEXT_NOT_SUPPORTED   5 /* not used */
#define USER_DATA_NOT_READABLE          6 /* not used */
#define NO_PSAP_AVAILABLE               7 /* not used */


typedef struct {

      /* start 8-octet aligned */

      /* common fields */
        u_int8  rpc_vers;		     /* 00:01 RPC version */
        u_int8  rpc_vers_minor;      /* 01:01 minor version */
        u_int8  PTYPE;		         /* 02:01 bind PDU */
		u_int8  pfc_flags;          /* 03:01 flags */
        byte    packed_drep[4];     /* 04:04 NDR data rep format label*/
        u_int16 frag_length;        /* 08:02 total length of fragment */
        u_int16 auth_length;        /* 10:02 length of auth_value */
        u_int32  call_id;           /* 12:04 call identifier */
} rpcconn_common_hdr_t;


typedef struct {

      /* start 8-octet aligned */

      /* common fields */
        u_int8  rpc_vers /*= 5*/;        /* 00:01 RPC version */
        u_int8  rpc_vers_minor;      /* 01:01 minor version */
        u_int8  PTYPE /*= bind*/;        /* 02:01 bind PDU */
        u_int8  pfc_flags;           /* 03:01 flags */
        byte    packed_drep[4];      /* 04:04 NDR data rep format label*/
        u_int16 frag_length;         /* 08:02 total length of fragment */
        u_int16 auth_length;         /* 10:02 length of auth_value */
        u_int32  call_id;            /* 12:04 call identifier */

      /* end common fields */

        u_int16 max_xmit_frag;     /* 16:02 max transmit frag size, bytes */
        u_int16 max_recv_frag;     /* 18:02 max receive  frag size, bytes */
        u_int32 assoc_group_id;    /* 20:04 incarnation of client-server
                                                            * assoc group */
      /* presentation context list */

        p_cont_list_t  p_context_elem; /* variable size */
    
      /* optional authentication verifier */
      /* following fields present iff auth_length != 0 */

        //auth_verifier_co_t   auth_verifier; 

        } rpcconn_bind_hdr_t;
        
        
typedef struct {

      /* start 8-octet aligned */

      /* common fields */
        u_int8  rpc_vers /*= 5*/;       /* 00:01 RPC version */
        u_int8  rpc_vers_minor ;    /* 01:01 minor version */
        u_int8  PTYPE /*= bind_ack*/;   /* 02:01 bind ack PDU */
        u_int8  pfc_flags;          /* 03:01 flags */
        byte    packed_drep[4];     /* 04:04 NDR data rep format label*/
        u_int16 frag_length;        /* 08:02 total length of fragment */
        u_int16 auth_length;        /* 10:02 length of auth_value */
        u_int32  call_id;           /* 12:04 call identifier */

      /* end common fields */

        u_int16 max_xmit_frag;      /* 16:02 max transmit frag size */
        u_int16 max_recv_frag;      /* 18:02 max receive  frag size */
        u_int32 assoc_group_id;     /* 20:04 returned assoc_group_id */
        port_any_t sec_addr;        /* 24:yy optional secondary address 
                                     * for process incarnation; local port
                                     * part of address only */
      /* restore 4-octet alignment */

        u_int8 pad2;    //WARNING: Assumes sec_addr size is 15 bytes

      /* presentation context result list, including hints */

        p_result_list_t     p_result_list;    /* variable size */

      /* optional authentication verifier */
      /* following fields present iff auth_length != 0 */

        //auth_verifier_co_t   auth_verifier; /* xx:yy */
    } rpcconn_bind_ack_hdr_t;
    
    
typedef struct {

      /* start 8-octet aligned */

      /* common fields */
        u_int8  rpc_vers /*= 5*/;       /* 00:01 RPC version */
        u_int8  rpc_vers_minor;     /* 01:01 minor version */
        u_int8  PTYPE /*= request*/ ;   /* 02:01 request PDU */
        u_int8  pfc_flags;          /* 03:01 flags */
        byte    packed_drep[4];     /* 04:04 NDR data rep format label*/
        u_int16 frag_length;        /* 08:02 total length of fragment */
        u_int16 auth_length;        /* 10:02 length of auth_value */
        u_int32  call_id;           /* 12:04 call identifier */

      /* end common fields */

      /* needed on request, response, fault */

        u_int32  alloc_hint;        /* 16:04 allocation hint */
        p_context_id_t p_cont_id;    /* 20:02 pres context, i.e. data rep */
        u_int16 opnum;              /* 22:02 operation # 
                                     * within the interface */

      /* optional field for request, only present if the PFC_OBJECT_UUID
         * field is non-zero */

        uuid_t  object;              /* 24:16 object UID */

      /* stub data, 8-octet aligned 
                   .
                   .
                   .                 */

      /* optional authentication verifier */
      /* following fields present iff auth_length != 0 */
 
        //auth_verifier_co_t   auth_verifier; /* xx:yy */

} rpcconn_request_hdr_t;


typedef struct {

      /* start 8-octet aligned */

      /* common fields */
	u_int8  rpc_vers /*= 5*/;        /* 00:01 RPC version */
	u_int8  rpc_vers_minor;      /* 01:01 minor version */
        u_int8  PTYPE /*= response*/;    /* 02:01 response PDU */
        u_int8  pfc_flags;           /* 03:01 flags */
        byte    packed_drep[4];      /* 04:04 NDR data rep format label*/
        u_int16 frag_length;         /* 08:02 total length of fragment */
        u_int16 auth_length;         /* 10:02 length of auth_value */
        u_int32 call_id;             /* 12:04 call identifier */

      /* end common fields */

      /* needed for request, response, fault */

        u_int32  alloc_hint;         /* 16:04 allocation hint */
        p_context_id_t p_cont_id;    /* 20:02 pres context, i.e. 
                                      * data rep */

      /* needed for response or fault */

        u_int8  cancel_count;         /* 22:01 cancel count */
        u_int8  reserved;            /* 23:01 reserved, m.b.z. */

      /* stub data here, 8-octet aligned
               .
               .
               .                          */

      /* optional authentication verifier */
      /* following fields present iff auth_length != 0 */

        //auth_verifier_co_t   auth_verifier; /* xx:yy */

} rpcconn_response_hdr_t;


