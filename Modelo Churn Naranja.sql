-----Armo esqueleto---
--Polizas Lapse 90---

select cast(ncProducto as varchar)+'-'+cast(npoliza as varchar)+'-'+cast(ncertificado as varchar) Solicitud_Contrato,
npoliza,
ncertificado,
ncproducto,
b.cdProducto Producto,
b.cdSeccion Ramo,
cdestado Estado,
miPremio Premio,
udInicioVigenciaInicial,
udAnulacion,
case when udAnulacion is null then DATEDIFF(day,udiniciovigenciaInicial,getdate()) 
	else DATEDIFF(day,udiniciovigenciaInicial,udAnulacion) end Dias_Vigente,
case when ncProducto in (152,157,232,301,3070) then 1 
	else 0 end Producto_Masivo,
case when DATEDIFF(day,udiniciovigenciaInicial,udAnulacion) <= 93 then 1 else 0 end Lapse_90,
cdocumento,
f.cdSexo, 
cast(cast(getdate()-udNacimiento as int)/365.25 as int) Edad,
d.cdProvincia
into #polizas_lapse90
from Dimensional.dbo.dhCertificado a with(nolock)
join Dimensional.dbo.diProducto b with(nolock) on a.ucProducto=b.ucProducto
join Dimensional.dbo.diPersona c with(nolock) on a.ucPersona=c.ucPersona
join Dimensional.dbo.diProvinciaRiesgo d with(nolock) on a.ucProvincia=d.ucProvincia
join Dimensional.dbo.diEstado e with(nolock) on a.ucEstado=e.ucEstado
join Dimensional.dbo.diSexo f with(nolock) on f.ucSexo=c.ucSexo
where ucMedioNegocio = 42
and udNacimiento < GETDATE()
and DATEDIFF(day,udiniciovigenciaInicial,udAnulacion) <= 93

----1.307.071

----Polizas vigentes 

select cast(ncProducto as varchar)+'-'+cast(npoliza as varchar)+'-'+cast(ncertificado as varchar) Solicitud_Contrato,
npoliza,
ncertificado,
ncproducto,
b.cdProducto Producto,
b.cdSeccion Ramo,
cdestado Estado,
miPremio Premio,
udInicioVigenciaInicial,
udAnulacion,
case when udAnulacion is null then DATEDIFF(day,udiniciovigenciaInicial,getdate()) 
	else DATEDIFF(day,udiniciovigenciaInicial,udAnulacion) end Dias_Vigente,
case when ncProducto in (152,157,232,301,3070) then 1 
	else 0 end Producto_Masivo,
case when DATEDIFF(day,udiniciovigenciaInicial,udAnulacion) <= 93 then 1 else 0 end Lapse_90,
cdocumento,
f.cdSexo, 
cast(cast(getdate()-udNacimiento as int)/365.25 as int) Edad,
d.cdProvincia
into #polizas_vigentes
from Dimensional.dbo.dhCertificado a with(nolock)
join Dimensional.dbo.diProducto b with(nolock) on a.ucProducto=b.ucProducto
join Dimensional.dbo.diPersona c with(nolock) on a.ucPersona=c.ucPersona
join Dimensional.dbo.diProvinciaRiesgo d with(nolock) on a.ucProvincia=d.ucProvincia
join Dimensional.dbo.diEstado e with(nolock) on a.ucEstado=e.ucEstado
join Dimensional.dbo.diSexo f with(nolock) on f.ucSexo=c.ucSexo
where ucMedioNegocio = 42
and udNacimiento < GETDATE()
and a.ucestado = 1 
and DATEDIFF(day,udiniciovigenciaInicial,getdate()) > 93

----2.051.100

----Borrar Provincia = Dato Erroneo
----Borrar Polizas con fecha InicioVigenciaInicial > getdate()

---Junto ambos
select *
into #polizas  ---3.358.171
from #polizas_lapse90
union ALL
select *
from #polizas_vigentes

---Levanto el punto de venta de Certificados----

select a.*, b.Medio_Venta_H, b.Punto_Venta_H, b.Puesto_Venta_H
into #polizas_2
from #polizas a
join [BUEV-PI3210DSQL].Migs.dbo.Certificados b with(nolock) on cast(a.npoliza as varchar)=b.nPolicy and a.nCertificado=b.ncertif and a.ncProducto=b.nproduct


----Borro duplis---
select npoliza, ncertificado, ncproducto, count(*) c
into #aux
from #polizas_2
group by npoliza, ncertificado, ncproducto
having count(*) > 1
---419

select a.*
into #final ---3.357.684
from #polizas_2 a
left join #aux b on a.ncProducto=b.ncProducto and a.nPoliza=b.nPoliza and a.nCertificado=b.nCertificado
where b.nPoliza is null



---Traigo de SAC segmento y renta de Naranja----

----Traigo el ultimo ingreso de todos los dni de Naranja que estan en la base----

select Num_Doc, max(a.id) id_ingreso
into #ultimo_ingreso ---1.815.050
from MKT_Data.dbo.SAC_INGRESO a with(nolock)
join MKT_Data.dbo.SAC_PERSONAS b with(nolock) on a.Id_Personas=b.Id
join #final c with(nolock) on b.Num_Doc=c.cDocumento
join MKT_Data.dbo.SAC_LOTES d with(Nolock) on a.Id_Lotes=d.Id
where d.Id_Canales = 13 and d.Id_Campanias not in (119, 22,111,130)
group by Num_Doc

---Traigo la info de segmento y etc---

select Num_Doc, 
dbo.UF_Extrae_Adicionales(b.Adicionales,'Rentabilidad') Rentabilidad,
dbo.UF_Extrae_Adicionales(b.Adicionales,'Segmento') Segmento
into #segmentos
from MKT_Data.dbo.SAC_INGRESO a with(nolock)
join MKT_Data.dbo.SAC_ADICIONALES b with(Nolock) on a.Id_Adicionales=b.id
join #ultimo_ingreso c on a.id=c.id_ingreso


---Meto todo en la tabla final
select a.*, 
case when len(Rentabilidad) =0 then null else Rentabilidad end Rentabilidad, 
case when len(Segmento) =0 then null else Segmento end Segmento,
RAND(CAST(CAST(newid() as binary(8)) as INT))*100 rdm
into MKT_DataTemp.dbo.Modelo_Churn_Naranja_Rama
from #final a
left join #segmentos b on a.cDocumento=b.Num_Doc
----3.361.708


---Arreglo los campos---
update MKT_DataTemp.dbo.Modelo_Churn_Naranja_Rama
set Rentabilidad = rtrim(ltrim(Rentabilidad)),
Segmento = rtrim(ltrim(Segmento))

update MKT_DataTemp.dbo.Modelo_Churn_Naranja_Rama
set Rentabilidad = null
where Rentabilidad in ('#N/A','0')

--Tomo una muestra ordenando aleatoriamente---

select top 300000 *
into #muestra
from MKT_DataTemp.dbo.Modelo_Churn_Naranja_Rama
where Rentabilidad is not null
and Segmento is not null
order by rdm


---Me quedo solo con las columnas necesarias
select Solicitud_Contrato,
npoliza,
ncertificado,
ncproducto,
Producto,
Ramo,
Estado,
Premio,
Producto_Masivo,
Lapse_90,
cdocumento,
cdSexo,
Edad,
cdProvincia,
Medio_Venta_H,
Punto_Venta_H,
Puesto_Venta_H,
Rentabilidad,
Segmento
into MKT_DataTemp.dbo.Modelo_Churn_Naranja_Muestra
from #muestra


select 
from MKT_DataTemp.dbo.Modelo_Churn_Naranja_Muestra