
sampler2D _VoxelTex;
float4 _VoxelTex_TexelSize;

float _LPVDimensions;
float _LPVDimensionsSquared;

float4 _LPV_AABBMin;
float4 _LPV_AABBMax;

float4 _LPV_Extents;

// Trilinear filtering
inline float4 triLerp(float2 texelSize, sampler2D volTex, float3 cell, float3 lerpVal, float lpvSize)
{
	float2 texA = float2(cell.x + cell.z * lpvSize, cell.y);
	texA.x /= lpvSize * lpvSize;
	texA.y /= lpvSize;

	float2 texB = float2(cell.x + cell.z * lpvSize + 1, cell.y);
	texB.x /= lpvSize * lpvSize;
	texB.y /= lpvSize;

	float2 texC = float2(cell.x + cell.z * lpvSize, cell.y + 1);
	texC.x /= lpvSize * lpvSize;
	texC.y /= lpvSize;

	float2 texD = float2(cell.x + cell.z * lpvSize + 1, cell.y + 1);
	texD.x /= lpvSize * lpvSize;
	texD.y /= lpvSize;

	cell.z += 1;

	float2 texE = float2(cell.x + cell.z * lpvSize, cell.y);
	texE.x /= lpvSize * lpvSize;
	texE.y /= lpvSize;

	float2 texF = float2(cell.x + cell.z * lpvSize + 1, cell.y);
	texF.x /= lpvSize * lpvSize;
	texF.y /= lpvSize;

	float2 texG = float2(cell.x + cell.z * lpvSize, cell.y + 1);
	texG.x /= lpvSize * lpvSize;
	texG.y /= lpvSize;

	float2 texH = float2(cell.x + cell.z * lpvSize + 1, cell.y + 1);
	texH.x /= lpvSize * lpvSize;
	texH.y /= lpvSize;

 	float4 sampleAA = tex2D(volTex, texA);
 	float4 sampleAB = tex2D(volTex, texB);

 	float4 aLerp = lerp(sampleAA, sampleAB, lerpVal.x);

	float4 sampleBA = tex2D(volTex, texC);
 	float4 sampleBB = tex2D(volTex, texD);

 	float4 bLerp = lerp(sampleBA, sampleBB, lerpVal.x);

	float4 sampleCA = tex2D(volTex, texE);
 	float4 sampleCB = tex2D(volTex, texF);

 	float4 cLerp = lerp(sampleCA, sampleCB, lerpVal.x);

 	float4 sampleDA = tex2D(volTex, texG);
 	float4 sampleDB = tex2D(volTex, texH);

 	float4 dLerp = lerp(sampleDA, sampleDB, lerpVal.x);

	float4 abLerp = lerp(aLerp, bLerp, lerpVal.y);
	float4 cdLerp = lerp(cLerp, dLerp, lerpVal.y);

	return lerp(abLerp, cdLerp, lerpVal.z);
}		

inline float3 CalcCellPos(float4 extents, float4 bmin, float4 bmax, float3 worldPos, float dimensions)
{
	float3 exactPos = ((worldPos - bmin.xyz) / extents.xyz) * dimensions; 
	return exactPos;
}

inline bool inside(float3 p, float3 minp, float3 maxp)
{
	if (p.x>maxp.x) return false;
	if (p.x<minp.x) return false;
	if (p.y>maxp.y) return false;
	if (p.y<minp.y) return false;
	if (p.z>maxp.z) return false;
	if (p.z<minp.z) return false;
	return true;
}	

inline float4 getSample(sampler2D volTex, float4 extents, float4 bmin, float4 bmax, float3 worldPos, float dimensions, float dimSquared, float2 texelSize)
{
	if(!inside(worldPos, bmin, bmax))
	{
		return 0;
	}

	float3 cellf = CalcCellPos(extents, bmin, bmax, worldPos, dimensions);
	
	
	
	int3 cell = floor(cellf);
	
	float xUV = (cell.x + cell.z * dimensions) / dimSquared;
	float yUV = cell.y / _LPVDimensions;			
	
	#ifdef VOXEL_POINT_SAMPLE
	return tex2D(volTex, float2(xUV, yUV));			
	#else
	return triLerp(texelSize.xy, volTex, cell, cellf - cell, dimensions);
	#endif
}

#define SAMPLE_GI(worldPos) getSample(_VoxelTex, _LPV_Extents, _LPV_AABBMin, _LPV_AABBMax, worldPos, _LPVDimensions, _LPVDimensionsSquared, _VoxelTex_TexelSize.xy);
